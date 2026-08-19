# App Download Barrier para Links Compartilhados

## Visão Geral

Esta funcionalidade adiciona uma barreira que exige o download do app mobile quando usuários acessam links de produtos através de links compartilhados de pastas.

## Como Funciona

### 1. Detecção de Acesso Compartilhado

O serviço `SharedLinkService` detecta automaticamente quando um usuário acessa a aplicação através de um link compartilhado, verificando query parameters na URL:

- `?shared=true` - Indica acesso via link compartilhado
- `?folder=nome_pasta` - Nome da pasta compartilhada
- `?user=user_id` ou `?from=user_id` - ID do usuário que compartilhou

**Exemplo de URL compartilhada:**
```
https://gimie.site/?shared=true&folder=Roupas%20de%20Ver%C3%A3o&user=abc123
```

### 2. Barreira no "Shop Now"

Quando um usuário acessa via link compartilhado e clica no botão "Shop Now":

1. O sistema detecta que é um acesso compartilhado
2. Em vez de abrir o link do produto, exibe um modal
3. O modal oferece opções para baixar o app na App Store ou Play Store
4. O usuário pode escolher baixar o app ou cancelar

### 3. Modal de Download

O modal (`AppDownloadModal`) apresenta:

- **Ícone visual** do app
- **Título**: "Baixe o App Gimie"
- **Descrição**: Explicação de que é necessário o app para acessar produtos
- **Botão App Store**: Para usuários iOS
- **Botão Play Store**: Para usuários Android
- **Botão "Agora não"**: Para fechar o modal

## Arquivos Criados/Modificados

### Novos Arquivos

1. **`lib/services/shared_link_service.dart`**
   - Serviço singleton para detectar e gerenciar acesso via links compartilhados
   - Métodos para verificar status, gerar URLs de compartilhamento

2. **`lib/widgets/app_download_modal.dart`**
   - Widget do modal de download
   - Botões para App Store e Play Store
   - Design consistente com o tema do app

### Arquivos Modificados

1. **`lib/main.dart`**
   - Inicialização do `SharedLinkService` no startup

2. **`lib/screens/folder_products_screen.dart`**
   - Verificação de acesso compartilhado antes de abrir produto
   - Exibição do modal quando necessário

3. **`lib/screens/home_screen.dart`**
   - Mesma lógica aplicada ao feed principal

4. **`lib/screens/add_product_screen.dart`**
   - Consistência na verificação de acesso compartilhado

## Como Usar

### Para Gerar Links de Compartilhamento

```dart
import 'package:gimie/services/shared_link_service.dart';

// Gerar URL de compartilhamento
final shareUrl = SharedLinkService.instance.generateShareUrl(
  userId: 'user123',
  folderName: 'Minha Pasta',
);

// shareUrl = "https://gimie.site/?shared=true&folder=Minha%20Pasta&user=user123"
```

### Para Verificar se é Acesso Compartilhado

```dart
import 'package:gimie/services/shared_link_service.dart';

final isShared = SharedLinkService.instance.isSharedAccess;

if (isShared) {
  // Lógica para acesso compartilhado
  final folderId = SharedLinkService.instance.sharedFolderId;
  final userId = SharedLinkService.instance.sharedUserId;
}
```

### Para Mostrar o Modal Manualmente

```dart
import 'package:gimie/widgets/app_download_modal.dart';

await AppDownloadModal.show(
  context,
  productUrl: 'https://example.com/product',
  onDismiss: () {
    // Callback opcional quando usuário cancela
  },
);
```

## Configuração das URLs das Lojas

As URLs da App Store e Play Store estão configuradas em:

`lib/widgets/app_download_modal.dart`:

```dart
static const String _appStoreUrl = 'https://apps.apple.com/br/app/gimie/id6768790198';
static const String _playStoreUrl = 'https://play.google.com/apps/test/com.gimie.app/7';
```

**✅ URLs configuradas e prontas para uso!**

## Fluxo do Usuário

```
1. Usuário recebe link compartilhado
   ↓
2. Clica no link e abre o navegador
   ↓
3. Web app carrega e detecta ?shared=true
   ↓
4. Usuário navega pela pasta compartilhada
   ↓
5. Usuário clica em "Shop Now" em um produto
   ↓
6. Modal de download aparece
   ↓
7. Usuário escolhe:
   - Download na App Store (iOS)
   - Download na Play Store (Android)
   - Agora não (fecha modal)
```

## Testes

Para testar localmente:

1. **Acesse com query parameters**:
   ```
   http://localhost:8080/?shared=true&folder=test&user=123
   ```

2. **Verifique o console** para ver a mensagem:
   ```
   Shared link detected - Folder: test, User: 123
   ```

3. **Clique em qualquer botão "Shop Now"**

4. **Verifique se o modal aparece** em vez de abrir o link do produto

### Teste Manual com setSharedAccess

```dart
// Para forçar modo compartilhado em testes
SharedLinkService.instance.setSharedAccess(
  isShared: true,
  folderId: 'test-folder',
  userId: 'test-user',
);

// Para limpar
SharedLinkService.instance.clear();
```

## Considerações Técnicas

### Web Only
- O serviço usa `dart:html` e só funciona na web
- Verifica `kIsWeb` antes de acessar APIs do navegador

### Detecção Automática
- A detecção acontece automaticamente no `main()` durante o startup
- Não requer configuração adicional

### State Management
- O estado é global via singleton
- Persiste durante toda a sessão do usuário

### Flexibilidade
- Aceita `?shared=true` ou `?from=user_id` como gatilhos
- Suporta múltiplos formatos de URL de compartilhamento

## Próximos Passos

1. ✅ Implementar detecção de links compartilhados
2. ✅ Criar modal de download
3. ✅ Integrar com botões "Shop Now"
4. ⏳ Atualizar URLs das lojas quando app for publicado
5. ⏳ Adicionar funcionalidade de compartilhar pastas na UI
6. ⏳ Implementar deep links para abrir pastas específicas
7. ⏳ Analytics para rastrear conversões de compartilhamento

## Suporte

Para questões ou melhorias, entre em contato com a equipe de desenvolvimento.
