import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/product_model.dart';
import '../utils/debug_helper.dart';

class ScrapingService {
  static final ScrapingService _instance = ScrapingService._internal();
  factory ScrapingService() => _instance;
  ScrapingService._internal();

  // URL da API Gimie 2.0 no Vercel
  static const String _scrapingApiUrl = ApiConfig.baseUrl;
  
  // Endpoints da API Gimie 2.0
  static const String _scrapeEndpoint = '/api/products';
  static const String _extractEndpoint = ApiConfig.extractEndpoint;
  static const String _healthEndpoint = '/health';
  static const String _suggestionsEndpoint = ApiConfig.suggestionsEndpoint;
  
  // Timeout para requisições
  static const Duration _timeout = Duration(seconds: 60);
  static const String _currencyValuePattern =
      r'(?:\d{1,3}(?:[.,]\d{3})+|\d+)(?:[.,]\d{2})?';
  
  /// Headers padrão para requisições
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'Gimie-App/1.0',
  };

  /// Verifica se a API de scraping está funcionando
  Future<bool> checkHealth() async {
    try {
      DebugHelper.log('Checking scraping API health', 'SCRAPING');
      
      final response = await http.get(
        Uri.parse('$_scrapingApiUrl$_healthEndpoint'),
        headers: _headers,
      ).timeout(_timeout);

      final isHealthy = response.statusCode == 200;
      DebugHelper.log('API health status: $isHealthy', 'SCRAPING');
      
      return isHealthy;
    } catch (e) {
      DebugHelper.logError('Health check failed', e);
      return false;
    }
  }

  /// Faz scraping de dados de produto a partir de uma URL
  Future<ScrapedProductData?> scrapeProductFromUrl(String url) async {
    try {
      DebugHelper.log('Scraping product from URL: $url', 'SCRAPING');
      
      if (!_isValidUrl(url)) {
        throw Exception('URL inválida fornecida');
      }

      // Local-first strategy:
      // 1) Try direct HTML extraction (more stable for many stores)
      // 2) Use external API only as secondary fallback
      final localData = await _extractFromPageHtml(url);
      if (localData != null && localData.hasValidData) {
        DebugHelper.log('Using local HTML scraping for: $url', 'SCRAPING');
        return localData;
      }

      final response = await http.post(
        Uri.parse('$_scrapingApiUrl$_scrapeEndpoint'),
        headers: _headers,
        body: jsonEncode({
          'url': url,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        // A nova API retorna um objeto com success e data
        if (responseData['success'] == true && responseData['data'] != null) {
          final productData = responseData['data'];
          final apiData = ScrapedProductData.fromGimieApi(productData);
          final htmlData = await _extractFromPageHtml(url);
          final scrapedData = _mergeApiAndHtmlData(
            apiData: apiData,
            htmlData: htmlData,
            url: url,
          );
          
          DebugHelper.log('Successfully scraped product: ${scrapedData.title}', 'SCRAPING');
          return scrapedData;
        } else {
          throw Exception('Resposta inválida da API: ${responseData['message'] ?? 'Dados não encontrados'}');
        }
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception('Erro de validação: ${error['message'] ?? 'URL inválida'}');
      } else if (response.statusCode == 404) {
        throw Exception('Produto não encontrado na URL fornecida');
      } else if (response.statusCode == 429) {
        throw Exception('Muitas requisições. Tente novamente em alguns minutos');
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Erro no servidor: ${error['message'] ?? 'Erro desconhecido'}');
      }
    } catch (e) {
      DebugHelper.logError('Scraping failed for URL: $url', e);
      if (e.toString().contains('URL inválida')) {
        rethrow;
      }
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Timeout: A página demorou muito para responder');
      }

      // Fallback local: tenta extrair metadados direto do HTML da página.
      final fallbackData = await _extractFromPageHtml(url);
      if (fallbackData != null && fallbackData.hasValidData) {
        DebugHelper.log('Using HTML fallback scraping for: $url', 'SCRAPING');
        return fallbackData;
      }

      // Não quebrar o fluxo do usuário quando a API cair.
      // Retornamos o link para permitir preenchimento manual.
      return ScrapedProductData(
        sourceUrl: url,
        scrapedAt: DateTime.now(),
      );
    }
  }

  static final RegExp _amazonHiResImageRe = RegExp(
    r'"hiRes"\s*:\s*"([^"]+)"',
    caseSensitive: false,
  );
  static final RegExp _amazonLargeImageRe = RegExp(
    r'"large"\s*:\s*"([^"]+)"',
    caseSensitive: false,
  );
  static final RegExp _amazonThumbImageRe = RegExp(
    r'"thumb"\s*:\s*"([^"]+)"',
    caseSensitive: false,
  );

  /// Amazon often serves a bot/captcha interstitial to mobile or generic clients,
  /// and puts gallery URLs in embedded JSON instead of `og:image`.
  bool _isAmazonProductUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    if (!host.contains('amazon.')) return false;
    final path = uri.path.toLowerCase();
    return path.contains('/dp/') ||
        path.contains('/gp/product/') ||
        path.contains('/d/') && RegExp(r'/d/[a-z0-9]{10}', caseSensitive: false).hasMatch(path);
  }

  String? _canonicalizeAbsoluteUrl(String? raw) {
    final t = raw?.trim();
    if (t == null || t.isEmpty) return null;
    if (t.startsWith('//')) return 'https:$t';
    return t;
  }

  /// Short, stable product URL for HTTP fetch (fewer ad/bot signals; Amazon ASIN path).
  String _canonicalizeStoreFetchUrl(String input) {
    final trimmed = input.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority) return trimmed;

    final host = uri.host.toLowerCase();

    if (host.contains('amazon.')) {
      final path = uri.path;
      final dp = RegExp(r'/dp/([A-Z0-9]{10})', caseSensitive: false).firstMatch(path);
      if (dp != null) {
        return '${uri.scheme}://${uri.host}/dp/${dp.group(1)}';
      }
      final gp = RegExp(r'/gp/product/([A-Z0-9]{10})', caseSensitive: false).firstMatch(path);
      if (gp != null) {
        return '${uri.scheme}://${uri.host}/dp/${gp.group(1)}';
      }
    }

    if (host.contains('magazineluiza.com.br') ||
        host.contains('magazinevoce.com.br')) {
      return '${uri.scheme}://${uri.host}${uri.path}';
    }

    // Moda / marketplaces: query só de campanha costuma piorar WAF; path basta.
    const marketingQueryStripHosts = [
      'shein.',
      'dafiti.',
      'zattini.',
      'renner.',
      'riachuelo.',
      'amaro.',
      'posthaus.',
    ];
    if (marketingQueryStripHosts.any(host.contains)) {
      return '${uri.scheme}://${uri.host}${uri.path}';
    }

    // VTEX / PDP: manter ids (skuId, idsku), tirar só rastreamento (utm, gclid, …).
    if (host.contains('cea.com') ||
        host.contains('hm.com.br') ||
        host.contains('arezzo.com.br')) {
      return _uriWithoutTrackingParameters(uri).toString();
    }

    return trimmed;
  }

  static const Set<String> _trackingQueryKeys = {
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    'gclid',
    'gbraid',
    'gad_source',
    'gad_campaignid',
    'gclsrc',
    'srsltid',
    'mcid',
    'tag',
    'linkcode',
    'hvadid',
    'hvrand',
    'partner_id',
    'hvexpln',
    'hvtargid',
    'hvdev',
    'hvnetw',
    'hvpos',
    'hvocijid',
  };

  Uri _uriWithoutTrackingParameters(Uri uri) {
    if (!uri.hasQuery) return uri;
    final qp = Map<String, String>.from(uri.queryParameters);
    qp.removeWhere((k, _) {
      final lk = k.toLowerCase();
      return _trackingQueryKeys.contains(lk) ||
          lk.startsWith('utm_') ||
          lk.startsWith('hv');
    });
    if (qp.isEmpty) {
      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: uri.path,
        fragment: uri.hasFragment ? uri.fragment : null,
      );
    }
    return uri.replace(queryParameters: qp);
  }

  String _refererForProductFetch(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.contains('magazineluiza.') || host.contains('magazinevoce.')) {
      return 'https://www.magazineluiza.com.br/';
    }
    if (host.contains('amazon.')) {
      return 'https://www.amazon.com.br/';
    }
    if (host.contains('mercadolivre.') || host.contains('mercadolibre.')) {
      return 'https://www.mercadolivre.com.br/';
    }
    if (host.contains('shopee.')) {
      return 'https://shopee.com.br/';
    }
    if (host.contains('shein.')) {
      return 'https://br.shein.com/';
    }
    if (host.contains('dafiti.')) {
      return 'https://www.dafiti.com.br/';
    }
    if (host.contains('zattini.')) {
      return 'https://www.zattini.com.br/';
    }
    if (host.contains('renner.')) {
      return 'https://www.lojasrenner.com.br/';
    }
    if (host.contains('cea.com')) {
      return 'https://www.cea.com.br/';
    }
    if (host.contains('riachuelo.')) {
      return 'https://www.riachuelo.com.br/';
    }
    if (host.contains('amaro.')) {
      return 'https://www.amaro.com/';
    }
    if (host.contains('posthaus.')) {
      return 'https://www.posthaus.com.br/';
    }
    if (host.contains('arezzo.')) {
      return 'https://www.arezzo.com.br/';
    }
    if (host.contains('hm.com.br')) {
      return 'https://www.hm.com.br/';
    }
    return '${Uri.tryParse(url)?.scheme ?? 'https'}://${Uri.tryParse(url)?.host ?? ''}/';
  }

  /// Lojas que costumam responder melhor a UA de desktop (anti-bot / SPA / og).
  bool _preferDesktopProductPageUa(String url) {
    if (_isAmazonProductUrl(url)) return true;
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    const desktopHints = [
      'mercadolivre.',
      'mercadolibre.',
      'shopee.',
      'magazineluiza.',
      'magazinevoce.',
      'olx.',
      'aliexpress.',
      'casasbahia.',
      'americanas.',
      'submarino.',
      'shoptime.',
      'temu.',
      'samsung.com',
      'shop.samsung',
      // Moda BR / fashion
      'shein.',
      'dafiti.',
      'zattini.',
      'renner.',
      'cea.com',
      'riachuelo.',
      'amaro.',
      'posthaus.',
      'arezzo.',
      'hm.com.br',
    ];
    return desktopHints.any(host.contains);
  }

  /// Picks a main product image from Amazon's inline JSON (gallery blocks).
  String? _extractAmazonGalleryImage(String html) {
    const needle = 'm.media-amazon.com/images/i/';
    bool looksLikeProductImage(String u) {
      final v = u.toLowerCase();
      if (!v.contains(needle)) return false;
      if (v.contains('prime_logo') || v.contains('brand-logo')) return false;
      return true;
    }

    String? firstMatch(RegExp re) {
      for (final m in re.allMatches(html)) {
        final raw = _normalizeText(m.group(1));
        if (raw == null || raw.isEmpty) continue;
        final u = raw.replaceAll(r'\/', '/');
        if (looksLikeProductImage(u)) return u;
      }
      return null;
    }

    return _firstNonEmpty([
      firstMatch(_amazonHiResImageRe),
      firstMatch(_amazonLargeImageRe),
      firstMatch(_amazonThumbImageRe),
    ]);
  }

  Map<String, String> _productPageRequestHeaders(String url) {
    final desktop = _preferDesktopProductPageUa(url);
    return {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      if (desktop) 'Accept-Language': 'pt-BR,pt;q=0.9,en-US,en;q=0.8',
      'Referer': _refererForProductFetch(url),
      if (desktop) ...{
        'Sec-Ch-Ua':
            '"Chromium";v="122", "Not(A:Brand";v="24", "Google Chrome";v="122"',
        'Sec-Ch-Ua-Mobile': '?0',
        'Sec-Ch-Ua-Platform': '"macOS"',
        'Upgrade-Insecure-Requests': '1',
      },
      'User-Agent': desktop
          ? 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
          : 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile',
    };
  }

  /// Mercado Livre often embeds gallery URLs as `secure_url` (mlstatic) before og:image hydrates.
  String? _extractMercadoLivreSecurePicture(String html) {
    final re = RegExp(
      r'"secure_url"\s*:\s*"(https?:[^"]+mlstatic[^"]+)"',
      caseSensitive: false,
    );
    final m = re.firstMatch(html);
    return _canonicalizeAbsoluteUrl(_normalizeText(m?.group(1)));
  }

  /// Shopee SSR sometimes includes a direct product image URL in JSON.
  String? _extractShopeeProductImage(String html) {
    final patterns = [
      RegExp(r'"image"\s*:\s*"(https://cf\.shopee[^"]+)"', caseSensitive: false),
      RegExp(r'"image"\s*:\s*"(https://down-br\.img\.susercontent\.com[^"]+)"', caseSensitive: false),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(html);
      final u = _canonicalizeAbsoluteUrl(_normalizeText(m?.group(1)));
      if (u != null && u.isNotEmpty) return u;
    }
    return null;
  }

  bool _skipNoiseProductImageUrl(String? u) {
    if (u == null || u.isEmpty) return true;
    final v = u.toLowerCase();
    return v.contains('logo') ||
        v.contains('favicon') ||
        v.contains('sprite') ||
        v.contains('placeholder') ||
        v.contains('/assets/') ||
        v.contains('social-sharing') ||
        v.contains('icon-bag') ||
        v.contains('cea-icons') ||
        v.endsWith('.svg');
  }

  String? _firstCdnMatch(String html, List<RegExp> patterns) {
    for (final re in patterns) {
      for (final m in re.allMatches(html)) {
        final u = _canonicalizeAbsoluteUrl(_normalizeText(m.group(1)));
        if (_skipNoiseProductImageUrl(u)) continue;
        return u;
      }
    }
    return null;
  }

  /// SHEIN: imagens em `img.ltwebstatic.com` dentro de JSON da PDP.
  String? _extractSheinProductImage(String html) {
    return _firstCdnMatch(html, [
      RegExp(
        r'"origin_image"\s*:\s*"(https://img\.ltwebstatic\.com[^"]+)"',
        caseSensitive: false,
      ),
      RegExp(
        r'"goods_img"\s*:\s*"(https://img\.ltwebstatic\.com[^"]+)"',
        caseSensitive: false,
      ),
      RegExp(
        r'"goodsImgs"\s*:\s*\[\s*"(https://img\.ltwebstatic\.com[^"]+)"',
        caseSensitive: false,
      ),
    ]);
  }

  /// Dafiti / Zattini: CDN estático no HTML ou JSON embutido.
  String? _extractDafitiZattiniStaticImage(String html) {
    return _firstCdnMatch(html, [
      RegExp(
        r'"(https://dafitistatic\.dafiti\.com\.br[^"]+\.(?:jpg|jpeg|png|webp))"',
        caseSensitive: false,
      ),
      RegExp(
        r'"(https://zattinistatic\.zattini\.com\.br[^"]+\.(?:jpg|jpeg|png|webp))"',
        caseSensitive: false,
      ),
    ]);
  }

  /// Lojas Renner — CDN `img.lojasrenner.com.br`.
  String? _extractRennerCdnImage(String html) {
    return _firstCdnMatch(html, [
      RegExp(
        r'"(https://img\.lojasrenner\.com\.br[^"]+\.(?:jpg|jpeg|png|webp))"',
        caseSensitive: false,
      ),
    ]);
  }

  /// C&A — `cdn.cea.com.br` ou imagens VTEX (`vteximg` / `vtexassets`).
  String? _extractCeaCdnImage(String html) {
    return _firstCdnMatch(html, [
      RegExp(
        r'"(https://cdn\.cea\.com\.br[^"]+\.(?:jpg|jpeg|png|webp))"',
        caseSensitive: false,
      ),
      RegExp(
        r'"(https://cea\.vteximg\.com\.br/arquivos/ids/\d+[^"]+\.(?:jpg|jpeg|png|webp))"',
        caseSensitive: false,
      ),
      RegExp(
        r'"(https://[^"]*vtexassets\.com[^"]*/arquivos/ids/\d+[^"]+\.(?:jpg|jpeg|png|webp))"',
        caseSensitive: false,
      ),
    ]);
  }

  /// Riachuelo — domínios estáticos comuns.
  String? _extractRiachueloCdnImage(String html) {
    return _firstCdnMatch(html, [
      RegExp(
        r'"(https://(?:mid|static|assets)\.riachuelo\.com\.br[^"]+\.(?:jpg|jpeg|png|webp))"',
        caseSensitive: false,
      ),
    ]);
  }

  /// Amaro — Shopify CDN na própria loja.
  String? _extractAmaroShopifyImage(String html) {
    return _firstCdnMatch(html, [
      RegExp(
        r'"(https://cdn\.shopify\.com/[^"]+\.(?:jpg|jpeg|png|webp))"',
        caseSensitive: false,
      ),
    ]);
  }

  /// Posthaus — URLs do próprio host/CDN no HTML.
  String? _extractPosthausImage(String html) {
    return _firstCdnMatch(html, [
      RegExp(
        r'"(https://static\.posthaus\.com\.br[^"]+\.(?:jpg|jpeg|png|webp))"',
        caseSensitive: false,
      ),
      RegExp(
        r'"(https://[^"]*posthaus[^"]+\.(?:jpg|jpeg|png|webp))"',
        caseSensitive: false,
      ),
    ]);
  }

  /// Arezzo — CDN `secure-static.arezzo.com.br` (além de `og:image`).
  String? _extractArezzoStaticImage(String html) {
    return _firstCdnMatch(html, [
      RegExp(
        r'"(https://secure-static\.arezzo\.com\.br[^"]+\.(?:jpg|jpeg|png|webp))"',
        caseSensitive: false,
      ),
    ]);
  }

  /// H&M Brasil — VTEX `hmbrasil.vtexassets.com` (além de `og:image`).
  String? _extractHmVtexProductImage(String html) {
    return _firstCdnMatch(html, [
      RegExp(
        r'"(https://hmbrasil\.vtexassets\.com[^"]+\.(?:jpg|jpeg|png|webp))"',
        caseSensitive: false,
      ),
    ]);
  }

  /// Amazon BR: buybox / widgets expose `value="R$ 183,00"` near displayString (NBSP ok via \\s).
  double? _extractAmazonDisplayStringPrice(String html) {
    if (!_isAmazonProductUrl(html)) return null;
    final re = RegExp(
      'displayString[^\\n]{0,120}value="(R\\\$\\s*$_currencyValuePattern)"',
      caseSensitive: false,
    );
    final candidates = <double>[];
    for (final m in re.allMatches(html)) {
      final p = _parsePriceFromString(m.group(1));
      if (p != null && p >= 1 && p < 1e7) candidates.add(p);
    }
    return _pickBestPriceCandidate(candidates);
  }

  /// Schema.org JSON-LD `Product` image (many BR stores: Magalu, Samsung, Casas Bahia, OLX listings).
  String? _extractJsonLdProductImage(String html) {
    final scriptRe = RegExp(
      '<script[^>]*type=[\'"]application/ld\\+json[\'"][^>]*>(.*?)</script>',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in scriptRe.allMatches(html)) {
      final raw = match.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;
      final fromBlock = _jsonLdImageFromDecodedBlock(raw);
      if (fromBlock != null) return fromBlock;
    }
    return null;
  }

  String? _jsonLdImageFromDecodedBlock(String raw) {
    dynamic tryDecode(String s) {
      try {
        return jsonDecode(s);
      } catch (_) {
        return null;
      }
    }

    Object? decoded = tryDecode(raw);
    if (decoded == null) {
      for (final piece in raw.split(RegExp(r'\r?\n'))) {
        final t = piece.trim();
        if (t.isEmpty || t == '{' || t == '}') continue;
        decoded = tryDecode(t);
        if (decoded != null) break;
      }
    }
    if (decoded == null) return null;
    final img = _jsonLdPickImageRecursive(decoded);
    return _canonicalizeAbsoluteUrl(img?.trim());
  }

  String? _jsonLdPickImageRecursive(Object? node) {
    if (node == null) return null;
    if (node is String) {
      if (node.startsWith('http') && !node.contains('schema.org')) return node;
      return null;
    }
    if (node is List) {
      for (final item in node) {
        final found = _jsonLdPickImageRecursive(item);
        if (found != null) return found;
      }
      return null;
    }
    if (node is! Map) return null;
    final map = Map<String, dynamic>.from(node);
    final type = map['@type'];
    final isProduct =
        (type is String && type.toString().toLowerCase() == 'product') ||
        (type is List &&
            type.map((e) => e.toString().toLowerCase()).contains('product'));

    if (isProduct) {
      final img = map['image'];
      if (img is String && img.startsWith('http')) return img;
      if (img is List && img.isNotEmpty) {
        final first = img.first;
        if (first is String && first.startsWith('http')) return first;
        if (first is Map) {
          final m = Map<String, dynamic>.from(first);
          final u = m['url'] ?? m['contentUrl'];
          if (u is String && u.startsWith('http')) return u;
        }
      }
      if (img is Map) {
        final im = Map<String, dynamic>.from(img);
        final u = im['url'] ?? im['contentUrl'];
        if (u is String && u.startsWith('http')) return u;
      }
    }

    if (map['@graph'] is List) {
      for (final item in map['@graph'] as List) {
        final found = _jsonLdPickImageRecursive(item);
        if (found != null) return found;
      }
    }
    for (final key in ['mainEntity', 'about', 'subjectOf']) {
      if (map[key] != null) {
        final found = _jsonLdPickImageRecursive(map[key]);
        if (found != null) return found;
      }
    }
    return null;
  }

  String? _extractSiteSpecificImage(String url, String html) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.contains('mercadolivre.') || host.contains('mercadolibre.')) {
      return _extractMercadoLivreSecurePicture(html);
    }
    if (host.contains('shopee.')) {
      return _extractShopeeProductImage(html);
    }
    if (host.contains('shein.')) {
      return _extractSheinProductImage(html);
    }
    if (host.contains('dafiti.') || host.contains('zattini.')) {
      return _extractDafitiZattiniStaticImage(html);
    }
    if (host.contains('renner.')) {
      return _extractRennerCdnImage(html);
    }
    if (host.contains('cea.com')) {
      return _extractCeaCdnImage(html);
    }
    if (host.contains('riachuelo.')) {
      return _extractRiachueloCdnImage(html);
    }
    if (host.contains('amaro.')) {
      return _extractAmaroShopifyImage(html);
    }
    if (host.contains('posthaus.')) {
      return _extractPosthausImage(html);
    }
    if (host.contains('arezzo.')) {
      return _extractArezzoStaticImage(html);
    }
    if (host.contains('hm.com.br')) {
      return _extractHmVtexProductImage(html);
    }
    return null;
  }

  Future<ScrapedProductData?> _extractFromPageHtml(String url) async {
    try {
      final fetchUrl = _canonicalizeStoreFetchUrl(url);
      final response = await http.get(
        Uri.parse(fetchUrl),
        headers: _productPageRequestHeaders(fetchUrl),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode < 200 || response.statusCode >= 400) {
        return null;
      }

      final html = response.body;
      final title = _firstNonEmpty([
        _extractMeta(html, 'property', 'og:title'),
        _extractMeta(html, 'name', 'twitter:title'),
        _extractTagTitle(html),
      ]);
      final image = _canonicalizeAbsoluteUrl(
        _firstNonEmpty([
          _extractMeta(html, 'property', 'og:image'),
          _extractMeta(html, 'name', 'twitter:image'),
          if (_isAmazonProductUrl(url)) _extractAmazonGalleryImage(html),
          _extractJsonLdProductImage(html),
          _extractSiteSpecificImage(url, html),
        ]),
      );
      final description = _firstNonEmpty([
        _extractMeta(html, 'property', 'og:description'),
        _extractMeta(html, 'name', 'description'),
      ]);

      final jsonLdPrice = _extractJsonLdPrice(html);
      final metaPriceRaw = _firstNonEmpty([
        _extractMeta(html, 'property', 'product:price:amount'),
        _extractMeta(html, 'name', 'price'),
      ]);
      final metaPrice = _parsePriceFromString(metaPriceRaw);
      final javaScriptPrice = _extractPriceFromJavaScript(html);
      final javaScriptPriceRaw = _extractPriceFromJavaScriptRaw(html);
      final discountedPriceRaw = _extractDiscountedPriceRawFromBody(html);
      final discountedPrice = _extractDiscountedPriceFromBody(html);
      final textPriceRaw = _extractPriceFromBodyRaw(html);
      final textPrice = _extractPriceFromBody(html);
      final amazonWidgetPrice = _extractAmazonDisplayStringPrice(html);
      final structuredPrice = _pickStructuredPrice(
        metaPrice: metaPrice,
        jsonLdPrice: jsonLdPrice,
        javaScriptPrice: javaScriptPrice,
      );
      final price = structuredPrice ??
          _pickBestPriceCandidate([
            amazonWidgetPrice,
            discountedPrice,
            textPrice,
          ]);
      final priceDisplay = _pickBestPriceDisplay([
        discountedPriceRaw,
        textPriceRaw,
        javaScriptPriceRaw,
        metaPriceRaw,
      ], preferredPrice: price);

      if ((title == null || title.isEmpty) &&
          (image == null || image.isEmpty) &&
          price == null) {
        return null;
      }

      return ScrapedProductData(
        title: title,
        description: description,
        price: price,
        priceDisplay: priceDisplay,
        imageUrl: image,
        sourceUrl: url,
        scrapedAt: DateTime.now(),
      );
    } catch (e) {
      DebugHelper.logError('HTML fallback extraction failed for $url', e);
      return null;
    }
  }

  ScrapedProductData _mergeApiAndHtmlData({
    required ScrapedProductData apiData,
    required ScrapedProductData? htmlData,
    required String url,
  }) {
    if (htmlData == null) return apiData;

    final htmlTitleValid =
        htmlData.title != null &&
        htmlData.title!.trim().isNotEmpty &&
        !_isGenericPageTitle(htmlData.title);
    final apiTitleValid =
        apiData.title != null &&
        apiData.title!.trim().isNotEmpty &&
        !_isGenericPageTitle(apiData.title);

    final mergedTitle = htmlTitleValid
        ? htmlData.title!.trim()
        : (apiTitleValid ? apiData.title!.trim() : null);

    final mergedDescription = (apiData.description?.trim().isNotEmpty ?? false)
        ? apiData.description!.trim()
        : htmlData.description?.trim();

    final mergedPrice = htmlData.price ?? apiData.price;
    final mergedPriceDisplay =
        (htmlData.priceDisplay?.trim().isNotEmpty ?? false)
            ? htmlData.priceDisplay!.trim()
            : apiData.priceDisplay;
    final mergedImage = (htmlData.imageUrl?.trim().isNotEmpty ?? false)
        ? htmlData.imageUrl!.trim()
        : apiData.imageUrl;

    return ScrapedProductData(
      title: mergedTitle,
      description: mergedDescription,
      price: mergedPrice,
      priceDisplay: mergedPriceDisplay,
      imageUrl: mergedImage,
      sourceUrl: url,
      additionalImages: ([
        ...?apiData.additionalImages,
        ...?htmlData.additionalImages,
      ]).toSet().toList(),
      metadata: {
        ...?apiData.metadata,
        ...?htmlData.metadata,
      },
      scrapedAt: DateTime.now(),
    );
  }

  String? _extractMeta(String html, String attrName, String attrValue) {
    final regex = RegExp(
      '<meta[^>]*$attrName=[\'"]${RegExp.escape(attrValue)}[\'"][^>]*content=[\'"]([^\'"]+)[\'"][^>]*>',
      caseSensitive: false,
    );
    final reverseRegex = RegExp(
      '<meta[^>]*content=[\'"]([^\'"]+)[\'"][^>]*$attrName=[\'"]${RegExp.escape(attrValue)}[\'"][^>]*>',
      caseSensitive: false,
    );
    final match = regex.firstMatch(html) ?? reverseRegex.firstMatch(html);
    return _normalizeText(match?.group(1));
  }

  String? _extractTagTitle(String html) {
    final match = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false)
        .firstMatch(html);
    return _normalizeText(match?.group(1));
  }

  double? _extractJsonLdPrice(String html) {
    final matches = RegExp(
      '<script[^>]*type=[\'"]application/ld\\+json[\'"][^>]*>(.*?)</script>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);

    for (final match in matches) {
      final raw = match.group(1);
      if (raw == null || raw.trim().isEmpty) continue;
      final candidate = _extractPriceFromJavaScript(raw) ?? _extractPriceFromBody(raw);
      if (candidate != null && candidate > 0) {
        return candidate;
      }
    }
    return null;
  }

  /// Tenta ler preços de JavaScript/JSON embutido no HTML.
  double? _extractPriceFromJavaScript(String text) {
    const preferredPriceKeys = [
      'price',
      'salePrice',
      'currentPrice',
      'bestPrice',
      'finalPrice',
      'specialPrice',
    ];

    const fallbackPriceKeys = [
      'listPrice',
      'priceValue',
      'spotPrice',
      'originalPrice',
      'compareAtPrice',
    ];

    final preferredCandidates = <double>[];
    for (final key in preferredPriceKeys) {
      final keyRegex = RegExp(
        '"$key"\\s*:\\s*"?([0-9][0-9.,]{0,20})"?',
        caseSensitive: false,
      );
      for (final match in keyRegex.allMatches(text)) {
        final candidate = _parsePriceFromString(match.group(1));
        if (candidate != null && candidate > 0 && candidate < 1000000) {
          preferredCandidates.add(candidate);
        }
      }
    }
    final bestPreferred = _pickMostFrequentThenBest(preferredCandidates);
    if (bestPreferred != null) return bestPreferred;

    final fallbackCandidates = <double>[];
    for (final key in fallbackPriceKeys) {
      final keyRegex = RegExp(
        '"$key"\\s*:\\s*"?([0-9][0-9.,]{0,20})"?',
        caseSensitive: false,
      );
      for (final match in keyRegex.allMatches(text)) {
        final candidate = _parsePriceFromString(match.group(1));
        if (candidate != null && candidate > 0 && candidate < 1000000) {
          fallbackCandidates.add(candidate);
        }
      }
    }

    return _pickMostFrequentThenBest(fallbackCandidates);
  }

  String? _extractPriceFromJavaScriptRaw(String text) {
    final matches = RegExp(
      '(?:R\\\$|US\\\$|\\\$|€)\\s?$_currencyValuePattern',
      caseSensitive: false,
    ).allMatches(text);
    final candidates = matches.map((m) => m.group(0)).whereType<String>();
    return _pickBestPriceDisplay(candidates);
  }

  /// Quando a página exibe preço cheio + promocional, prioriza o menor
  /// encontrado em contextos que indicam preço vigente.
  double? _extractDiscountedPriceFromBody(String html) {
    final contextualMatches = RegExp(
      '(?:(?:promo|sale|special|current|now|final|desconto|oferta|por|preço atual)[^<]{0,120})((?:R\\\$|US\\\$|\\\$|€)\\s?$_currencyValuePattern)',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);

    final candidates = <double>[];
    for (final match in contextualMatches) {
      final parsed = _parsePriceFromString(match.group(1));
      if (parsed != null && parsed > 0) {
        final contextWindow = _extractContextWindow(
          html,
          match.start,
          match.end,
          radius: 80,
        );
        if (!_looksLikeInstallmentContext(contextWindow)) {
          candidates.add(parsed);
        }
      }
    }

    if (candidates.isNotEmpty) {
      return _pickBestPriceCandidate(candidates);
    }

    final genericMatches = RegExp(
      '(R\\\$|US\\\$|\\\$|€)\\s?$_currencyValuePattern',
      caseSensitive: false,
    ).allMatches(html);
    for (final match in genericMatches.take(20)) {
      final parsed = _parsePriceFromString(match.group(0));
      if (parsed != null && parsed > 0) {
        final contextWindow = _extractContextWindow(
          html,
          match.start,
          match.end,
          radius: 100,
        );
        if (_looksLikeInstallmentContext(contextWindow)) continue;
        candidates.add(parsed);
      }
    }
    return _pickBestPriceCandidate(candidates);
  }

  String? _extractDiscountedPriceRawFromBody(String html) {
    final contextualMatches = RegExp(
      '(?:(?:promo|sale|special|current|now|final|desconto|oferta|por|preço atual)[^<]{0,120})((?:R\\\$|US\\\$|\\\$|€)\\s?$_currencyValuePattern)',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);

    final contextual = contextualMatches
        .where((match) {
          final contextWindow = _extractContextWindow(
            html,
            match.start,
            match.end,
            radius: 80,
          );
          return !_looksLikeInstallmentContext(contextWindow);
        })
        .map((match) => match.group(1))
        .whereType<String>()
        .toList();
    if (contextual.isNotEmpty) return _pickBestPriceDisplay(contextual);

    final genericMatches = RegExp(
      '(R\\\$|US\\\$|\\\$|€)\\s?$_currencyValuePattern',
      caseSensitive: false,
    ).allMatches(html);
    return _pickBestPriceDisplay(
      genericMatches
          .where((match) {
            final contextWindow = _extractContextWindow(
              html,
              match.start,
              match.end,
              radius: 100,
            );
            return !_looksLikeInstallmentContext(contextWindow);
          })
          .map((match) => match.group(0))
          .whereType<String>(),
    );
  }

  double? _extractPriceFromBody(String html) {
    final matches = RegExp(
      '((R\\\$|US\\\$|\\\$|€)\\s?$_currencyValuePattern)',
      caseSensitive: false,
    ).allMatches(html);

    for (final match in matches) {
      final contextWindow = _extractContextWindow(
        html,
        match.start,
        match.end,
        radius: 100,
      );
      if (_looksLikeInstallmentContext(contextWindow)) continue;
      return _parsePriceFromString(match.group(1));
    }
    return null;
  }

  String? _extractPriceFromBodyRaw(String html) {
    final matches = RegExp(
      '((R\\\$|US\\\$|\\\$|€)\\s?$_currencyValuePattern)',
      caseSensitive: false,
    ).allMatches(html);
    for (final match in matches) {
      final contextWindow = _extractContextWindow(
        html,
        match.start,
        match.end,
        radius: 100,
      );
      if (_looksLikeInstallmentContext(contextWindow)) continue;
      return match.group(1)?.trim();
    }
    return null;
  }

  String _extractContextWindow(
    String text,
    int start,
    int end, {
    int radius = 80,
  }) {
    final from = (start - radius).clamp(0, text.length);
    final to = (end + radius).clamp(0, text.length);
    return text.substring(from, to).toLowerCase();
  }

  bool _looksLikeInstallmentContext(String context) {
    if (context.isEmpty) return false;
    final markers = <RegExp>[
      RegExp(r'parcelad'),
      RegExp(r'parcela'),
      RegExp(r'sem juros'),
      RegExp(r'juros'),
      RegExp(r'no cart[aã]o'),
      RegExp(r'em at[eé]'),
      RegExp(r'\d{1,2}\s*x\s*de'),
      RegExp(r'\d{1,2}\s*vezes'),
    ];
    return markers.any((marker) => marker.hasMatch(context));
  }

  double? _parsePriceFromString(String? raw) {
    return _parseFlexiblePrice(raw);
  }

  double? _pickBestPriceCandidate(Iterable<double?> values) {
    final candidates = values
        .whereType<double>()
        .where((value) => value > 0 && value < 1000000)
        .toList()
      ..sort();
    if (candidates.isEmpty) return null;

    // Evita capturar preço de parcela/frete muito baixo quando há preço real.
    if (candidates.length > 1 && candidates.first < 10 && candidates.last > 100) {
      candidates.removeAt(0);
    }

    // Remove outliers baixos (ex.: parcela 109 quando preço real é 1098).
    while (candidates.length > 1) {
      final first = candidates[0];
      final second = candidates[1];
      final ratio = second / first;
      if (ratio >= 4.5) {
        candidates.removeAt(0);
        continue;
      }
      break;
    }

    return candidates.first;
  }

  String? _pickBestPriceDisplay(
    Iterable<String?> values, {
    double? preferredPrice,
  }) {
    final withValues = values
        .whereType<String>()
        .map((raw) => raw.trim())
        .where((raw) => raw.isNotEmpty)
        .map((raw) => MapEntry(raw, _parsePriceFromString(raw)))
        .where((entry) => entry.value != null && entry.value! > 0)
        .map((entry) => MapEntry(entry.key, entry.value!))
        .toList();

    if (withValues.isEmpty) return null;

    if (preferredPrice != null && preferredPrice > 0) {
      withValues.sort((a, b) {
        final diffA = (a.value - preferredPrice).abs();
        final diffB = (b.value - preferredPrice).abs();
        return diffA.compareTo(diffB);
      });
      return withValues.first.key;
    }

    withValues.sort((a, b) => a.value.compareTo(b.value));

    if (withValues.length > 1 &&
        withValues.first.value < 10 &&
        withValues.last.value > 100) {
      withValues.removeAt(0);
    }

    while (withValues.length > 1) {
      final ratio = withValues[1].value / withValues[0].value;
      if (ratio >= 4.5) {
        withValues.removeAt(0);
        continue;
      }
      break;
    }

    return withValues.first.key;
  }

  double? _pickMostFrequentThenBest(List<double> values) {
    if (values.isEmpty) return null;

    final frequencies = <int, int>{};
    for (final value in values) {
      final cents = (value * 100).round();
      frequencies[cents] = (frequencies[cents] ?? 0) + 1;
    }

    var bestCount = 0;
    final mostFrequent = <double>[];
    frequencies.forEach((cents, count) {
      final price = cents / 100.0;
      if (count > bestCount) {
        bestCount = count;
        mostFrequent
          ..clear()
          ..add(price);
      } else if (count == bestCount) {
        mostFrequent.add(price);
      }
    });

    return _pickBestPriceCandidate(mostFrequent);
  }

  double? _pickStructuredPrice({
    required double? metaPrice,
    required double? jsonLdPrice,
    required double? javaScriptPrice,
  }) {
    // Product metadata is usually the most reliable source for PDP pages.
    if (metaPrice != null && metaPrice > 0) return metaPrice;
    if (jsonLdPrice != null && jsonLdPrice > 0) return jsonLdPrice;

    if (javaScriptPrice != null && javaScriptPrice > 0) {
      return javaScriptPrice;
    }
    return null;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String? _normalizeText(String? text) {
    if (text == null) return null;
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  bool _isGenericPageTitle(String? value) {
    final text = value?.trim().toLowerCase() ?? '';
    if (text.isEmpty) return true;
    const genericMarkers = [
      'resultado da busca',
      'resultados da busca',
      'search result',
      'search results',
      'catalogo',
      'catálogo',
      'colecao',
      'coleção',
      'home',
      'início',
      'inicio',
    ];
    return genericMarkers.any(text.contains);
  }

  /// Extrai dados específicos de uma página web
  Future<Map<String, dynamic>?> extractDataFromUrl({
    required String url,
    List<String>? selectors,
    bool extractMetadata = true,
  }) async {
    try {
      DebugHelper.log('Extracting data from URL: $url', 'SCRAPING');

      final body = <String, dynamic>{
        'url': url,
        'extractMetadata': extractMetadata,
      };

      if (selectors != null && selectors.isNotEmpty) {
        body['selectors'] = selectors;
      }

      final response = await http.post(
        Uri.parse('$_scrapingApiUrl$_extractEndpoint'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        DebugHelper.log('Successfully extracted data', 'SCRAPING');
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Erro na extração: ${error['message'] ?? 'Erro desconhecido'}');
      }
    } catch (e) {
      DebugHelper.logError('Data extraction failed for URL: $url', e);
      rethrow;
    }
  }

  /// Faz scraping em lote de múltiplas URLs
  Future<List<ScrapedProductData>> scrapeBatchUrls(List<String> urls) async {
    try {
      DebugHelper.log('Scraping batch of ${urls.length} URLs', 'SCRAPING');
      
      final results = <ScrapedProductData>[];
      
      // Processa URLs em lotes para evitar sobrecarga
      const batchSize = 5;
      for (int i = 0; i < urls.length; i += batchSize) {
        final batch = urls.skip(i).take(batchSize).toList();
        final batchResults = await Future.wait(
          batch.map((url) => scrapeProductFromUrl(url).catchError((e) {
            DebugHelper.logError('Failed to scrape URL in batch: $url', e);
            return null;
          })),
        );
        
        results.addAll(batchResults.where((result) => result != null).cast<ScrapedProductData>());
        
        // Pequena pausa entre lotes para não sobrecarregar o servidor
        if (i + batchSize < urls.length) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      DebugHelper.log('Batch scraping completed: ${results.length} successful', 'SCRAPING');
      return results;
    } catch (e) {
      DebugHelper.logError('Batch scraping failed', e);
      rethrow;
    }
  }

  /// Converte dados scraped para modelo de produto do app
  Product convertScrapedDataToProduct({
    required ScrapedProductData scrapedData,
    required String userId,
    String? category,
  }) {
    return Product(
      id: '', // Será gerado pelo Firebase
      name: scrapedData.title ?? 'Produto sem nome',
      description: scrapedData.description ?? 'Sem descrição',
      price: scrapedData.price ?? 0.0,
      priceDisplay: scrapedData.priceDisplay,
      imageUrl: scrapedData.imageUrl ?? '',
      url: scrapedData.sourceUrl,
      userId: userId,
      category: category ?? _inferCategoryFromData(scrapedData),
      likes: 0,
      likedBy: [],
      createdAt: DateTime.now(),
    );
  }

  /// Infere categoria baseada nos dados do produto
  String _inferCategoryFromData(ScrapedProductData data) {
    final title = data.title?.toLowerCase() ?? '';
    final description = data.description?.toLowerCase() ?? '';
    final content = '$title $description';

    if (content.contains('eletrônico') || content.contains('smartphone') || content.contains('laptop')) {
      return 'Eletrônicos';
    } else if (content.contains('roupa') || content.contains('camisa') || content.contains('calça')) {
      return 'Moda';
    } else if (content.contains('casa') || content.contains('decoração') || content.contains('móvel')) {
      return 'Casa';
    } else if (content.contains('beleza') || content.contains('cosmético') || content.contains('perfume')) {
      return 'Beleza';
    } else if (content.contains('esporte') || content.contains('fitness') || content.contains('academia')) {
      return 'Esportes';
    } else if (content.contains('livro') || content.contains('literatura') || content.contains('educação')) {
      return 'Livros';
    }
    
    return 'Outros';
  }

  /// Valida se uma URL é válida
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https') && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  /// Obtém sugestões de produtos baseado em uma categoria
  Future<List<ScrapedProductData>> getProductSuggestions(String category) async {
    try {
      DebugHelper.log('Getting product suggestions for category: $category', 'SCRAPING');
      
      final response = await http.get(
        Uri.parse('$_scrapingApiUrl$_suggestionsEndpoint?category=${Uri.encodeComponent(category)}'),
        headers: _headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> suggestions = data['suggestions'] ?? [];
        
        return suggestions
            .map((json) => ScrapedProductData.fromJson(json))
            .toList();
      } else {
        DebugHelper.log('No suggestions available for category: $category', 'SCRAPING');
        return [];
      }
    } catch (e) {
      DebugHelper.logError('Failed to get suggestions for category: $category', e);
      return [];
    }
  }

  /// Limpa cache do serviço de scraping
  Future<bool> clearCache() async {
    try {
      // Endpoint de cache nao esta publicado na API 2.0 atual.
      if (!ApiConfig.isEndpointAvailableInApi2('/api/cache')) {
        return false;
      }

      final response = await http.delete(
        Uri.parse('$_scrapingApiUrl/api/cache'),
        headers: _headers,
      ).timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      DebugHelper.logError('Failed to clear cache', e);
      return false;
    }
  }
}

/// Modelo para dados de produto extraídos via scraping
class ScrapedProductData {
  final String? title;
  final String? description;
  final double? price;
  final String? priceDisplay;
  final String? imageUrl;
  final String sourceUrl;
  final List<String>? additionalImages;
  final Map<String, dynamic>? metadata;
  final DateTime scrapedAt;

  ScrapedProductData({
    this.title,
    this.description,
    this.price,
    this.priceDisplay,
    this.imageUrl,
    required this.sourceUrl,
    this.additionalImages,
    this.metadata,
    required this.scrapedAt,
  });

  factory ScrapedProductData.fromJson(Map<String, dynamic> json) {
    final rawPriceDisplay = json['priceDisplay'] ?? json['price_display'];
    return ScrapedProductData(
      title: json['title'] as String?,
      description: json['description'] as String?,
      price: _parsePrice(json['price']),
      priceDisplay: rawPriceDisplay?.toString(),
      imageUrl: json['imageUrl'] as String? ?? json['image'] as String?,
      sourceUrl: json['sourceUrl'] as String? ?? json['url'] as String? ?? '',
      additionalImages: (json['additionalImages'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      scrapedAt: DateTime.tryParse(json['scrapedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Factory constructor para dados da Gimie API 2.0
  factory ScrapedProductData.fromGimieApi(Map<String, dynamic> json) {
    final apiPrice = _pickBestApiPrice(json);
    final apiPriceDisplay = _pickBestApiPriceDisplay(json);
    return ScrapedProductData(
      title: json['name'] as String? ?? json['title'] as String?,
      description: json['description'] as String?,
      price: apiPrice,
      priceDisplay: apiPriceDisplay,
      imageUrl: json['image'] as String? ?? json['imageUrl'] as String?,
      sourceUrl: json['url'] as String? ?? json['sourceUrl'] as String? ?? '',
      additionalImages: (json['images'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      metadata: {
        'currency': json['currency'],
        'originalPrice': json['originalPrice'],
        'convertedPrice': json['convertedPrice'],
        'domain': json['domain'],
        'site': json['site'],
        'id': json['id'],
        ...?json['metadata'] as Map<String, dynamic>?,
      },
      scrapedAt: DateTime.tryParse(json['createdAt'] as String? ?? json['scrapedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'priceDisplay': priceDisplay,
      'imageUrl': imageUrl,
      'sourceUrl': sourceUrl,
      'additionalImages': additionalImages,
      'metadata': metadata,
      'scrapedAt': scrapedAt.toIso8601String(),
    };
  }

  static double? _parsePrice(dynamic price) {
    return _parseFlexiblePrice(price);
  }

  static double? _pickBestApiPrice(Map<String, dynamic> json) {
    final preferred = <double?>[
      _parsePrice(json['salePrice']),
      _parsePrice(json['specialPrice']),
      _parsePrice(json['finalPrice']),
      _parsePrice(json['currentPrice']),
      _parsePrice(json['price']),
    ];
    final bestPreferred = _pickLowestReasonable(preferred);
    if (bestPreferred != null) return bestPreferred;

    return _pickLowestReasonable([
      _parsePrice(json['originalPrice']),
      _parsePrice(json['listPrice']),
      _parsePrice(json['compareAtPrice']),
      _parsePrice(json['amount']),
    ]);
  }

  static String? _pickBestApiPriceDisplay(Map<String, dynamic> json) {
    final candidates = <String?>[
      json['priceDisplay']?.toString(),
      json['displayPrice']?.toString(),
      json['formattedPrice']?.toString(),
      json['salePriceFormatted']?.toString(),
      json['finalPriceFormatted']?.toString(),
      json['priceFormatted']?.toString(),
      json['salePrice']?.toString(),
      json['finalPrice']?.toString(),
      json['currentPrice']?.toString(),
      json['price']?.toString(),
      json['originalPrice']?.toString(),
    ]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    for (final candidate in candidates) {
      if (RegExp(r'(R\$|US\$|\$|€)').hasMatch(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  static double? _pickLowestReasonable(Iterable<double?> values) {
    final candidates = values
        .whereType<double>()
        .where((value) => value > 0 && value < 1000000)
        .toList()
      ..sort();
    if (candidates.isEmpty) return null;
    if (candidates.length > 1 && candidates.first < 10 && candidates.last > 100) {
      candidates.removeAt(0);
    }

    while (candidates.length > 1) {
      final first = candidates[0];
      final second = candidates[1];
      final ratio = second / first;
      if (ratio >= 4.5) {
        candidates.removeAt(0);
        continue;
      }
      break;
    }

    return candidates.first;
  }

  bool get hasValidData {
    final hasTitle = title != null && title!.trim().isNotEmpty;
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final hasPrice = price != null && price! > 0;
    // Do not treat `sourceUrl` alone as valid — otherwise bot/captcha pages
    // short-circuit the pipeline before the API fallback.
    return hasTitle || hasImage || hasPrice;
  }
}

double? _parseFlexiblePrice(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();

  final raw = value.toString().trim();
  if (raw.isEmpty) return null;

  var clean = raw.replaceAll(RegExp(r'[^\d.,]'), '');
  if (clean.isEmpty) return null;

  final lastComma = clean.lastIndexOf(',');
  final lastDot = clean.lastIndexOf('.');

  if (lastComma >= 0 && lastDot >= 0) {
    if (lastComma > lastDot) {
      // Formato BR: 1.234,56
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // Formato US: 1,234.56
      clean = clean.replaceAll(',', '');
    }
  } else if (lastComma >= 0) {
    final decimals = clean.length - lastComma - 1;
    if (decimals == 2) {
      clean = clean.replaceAll(',', '.');
    } else {
      // Ex: 1,500
      clean = clean.replaceAll(',', '');
    }
  } else if (lastDot >= 0) {
    final decimals = clean.length - lastDot - 1;
    if (decimals == 2) {
      // Ex: 1500.99
    } else {
      // Ex: 1.500 (milhar)
      clean = clean.replaceAll('.', '');
    }
  }

  return double.tryParse(clean);
}