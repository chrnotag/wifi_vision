# 🤝 Guia de Contribuição - WiFi Vision

Obrigado por seu interesse em contribuir com o projeto **WiFi Vision**! Este documento fornece diretrizes e informações para contribuidores.

## 📋 Índice

- [Como Contribuir](#como-contribuir)
- [Configuração do Ambiente](#configuração-do-ambiente)
- [Padrões de Código](#padrões-de-código)
- [Processo de Pull Request](#processo-de-pull-request)
- [Áreas de Contribuição](#áreas-de-contribuição)
- [Reportando Bugs](#reportando-bugs)
- [Solicitando Features](#solicitando-features)

## 🚀 Como Contribuir

### 1. Fork e Clone

```bash
# Faça fork do repositório
# Clone seu fork localmente
git clone https://github.com/SEU_USUARIO/wifi_vision.git
cd wifi_vision

# Adicione o repositório original como upstream
git remote add upstream https://github.com/chrnotag/wifi_vision.git
```

### 2. Crie uma Branch

```bash
# Crie uma branch para sua feature
git checkout -b feature/nome-da-feature

# Ou para correção de bugs
git checkout -b fix/nome-do-bug
```

### 3. Faça suas Alterações

- Implemente suas mudanças seguindo os padrões do projeto
- Adicione testes quando apropriado
- Atualize a documentação se necessário

### 4. Commit e Push

```bash
# Adicione suas mudanças
git add .

# Faça commit com mensagem descritiva
git commit -m "feat: adiciona nova funcionalidade de detecção"

# Push para sua branch
git push origin feature/nome-da-feature
```

### 5. Abra um Pull Request

- Vá para o repositório original no GitHub
- Clique em "New Pull Request"
- Selecione sua branch
- Descreva suas mudanças detalhadamente

## 🛠️ Configuração do Ambiente

### Pré-requisitos

- **Flutter SDK**: 3.8.1 ou superior
- **Dart SDK**: 3.0.0 ou superior
- **Android Studio** ou **VS Code**
- **Dispositivo Android** para testes

### Instalação

```bash
# Clone o repositório
git clone https://github.com/chrnotag/wifi_vision.git
cd wifi_vision

# Instale as dependências
flutter pub get

# Execute o projeto
flutter run
```

### Dependências de Desenvolvimento

```bash
# Instale dependências de desenvolvimento
flutter pub get --dev

# Execute os testes
flutter test

# Verifique a qualidade do código
flutter analyze
```

## 📝 Padrões de Código

### Convenções de Nomenclatura

- **Classes**: PascalCase (ex: `WiFiService`)
- **Variáveis e métodos**: camelCase (ex: `scanWiFiNetworks`)
- **Constantes**: SCREAMING_SNAKE_CASE (ex: `MAX_RSSI`)
- **Arquivos**: snake_case (ex: `wifi_service.dart`)

### Estrutura de Arquivos

```
lib/
├── main.dart              # Ponto de entrada da aplicação
├── services/              # Serviços e lógica de negócio
├── models/                # Modelos de dados
├── views/                 # Telas e widgets
├── utils/                 # Utilitários e helpers
└── constants/             # Constantes da aplicação
```

### Padrões de Código

- Use **BLoC** para gerenciamento de estado
- Documente funções públicas com comentários
- Mantenha funções pequenas e focadas
- Use tipos explícitos quando possível
- Trate erros adequadamente

### Exemplo de Código

```dart
/// Escaneia redes WiFi disponíveis e retorna uma lista de APs
/// 
/// [currentHeading] - Direção atual em graus (0-360)
/// Retorna uma lista de redes WiFi detectadas
Future<List<WiFiAP>> scanWiFiNetworks(double currentHeading) async {
  try {
    // Implementação...
  } catch (e) {
    print('Erro no scan WiFi: $e');
    return _getFallbackAPs(currentHeading);
  }
}
```

## 🔄 Processo de Pull Request

### Checklist do Pull Request

- [ ] Código segue os padrões do projeto
- [ ] Testes passam localmente
- [ ] Documentação foi atualizada
- [ ] Não há conflitos de merge
- [ ] Descrição clara das mudanças

### Template do Pull Request

```markdown
## Descrição
Breve descrição das mudanças implementadas.

## Tipo de Mudança
- [ ] Bug fix
- [ ] Nova feature
- [ ] Breaking change
- [ ] Documentação

## Testes
- [ ] Testes unitários passam
- [ ] Testes de integração passam
- [ ] Testado em dispositivo real

## Screenshots (se aplicável)
Adicione screenshots das mudanças visuais.

## Checklist
- [ ] Código segue os padrões do projeto
- [ ] Self-review do código
- [ ] Comentários explicam código complexo
- [ ] Documentação atualizada
```

## 🎯 Áreas de Contribuição

### 🧠 Algoritmos e Processamento de Sinal

- **Marching Squares**: Melhorias na detecção de contornos
- **RDP Simplifier**: Otimização da simplificação de polígonos
- **Triangulação**: Algoritmos de geração de malhas 3D
- **Filtros**: Novos filtros de processamento de sinal

### 📱 Interface do Usuário

- **Design**: Melhorias no design e UX
- **Responsividade**: Adaptação para diferentes tamanhos de tela
- **Acessibilidade**: Suporte para usuários com necessidades especiais
- **Temas**: Novos temas e personalização

### 🔧 Infraestrutura

- **Testes**: Cobertura de testes e testes automatizados
- **CI/CD**: Pipelines de integração contínua
- **Documentação**: Melhorias na documentação técnica
- **Performance**: Otimizações de performance

### 🌐 Integração WiFi

- **Hardware**: Suporte para novos tipos de hardware
- **Protocolos**: Implementação de novos protocolos WiFi
- **Calibração**: Sistemas de calibração automática
- **Interferência**: Melhorias na detecção de interferência

## 🐛 Reportando Bugs

### Como Reportar um Bug

1. **Verifique se já foi reportado**: Procure em issues existentes
2. **Use o template**: Preencha o template de bug report
3. **Seja específico**: Inclua passos para reproduzir
4. **Adicione logs**: Inclua logs de erro quando possível

### Template de Bug Report

```markdown
## Descrição do Bug
Descrição clara e concisa do bug.

## Passos para Reproduzir
1. Vá para '...'
2. Clique em '...'
3. Role para baixo até '...'
4. Veja o erro

## Comportamento Esperado
O que deveria acontecer.

## Comportamento Atual
O que está acontecendo.

## Screenshots
Se aplicável, adicione screenshots.

## Ambiente
- Dispositivo: [ex: Samsung Galaxy S21]
- Android: [ex: 12]
- Versão do App: [ex: 1.0.0]
- Flutter: [ex: 3.8.1]

## Logs
Adicione logs relevantes aqui.
```

## 💡 Solicitando Features

### Como Solicitar uma Feature

1. **Descreva o problema**: Explique por que a feature é necessária
2. **Proponha uma solução**: Como você gostaria que funcionasse
3. **Alternativas**: Considere alternativas que você já tentou
4. **Contexto adicional**: Qualquer contexto adicional

### Template de Feature Request

```markdown
## Problema
Descrição clara do problema que a feature resolveria.

## Solução Proposta
Descrição da solução desejada.

## Alternativas Consideradas
Alternativas que você já considerou.

## Contexto Adicional
Qualquer contexto adicional, screenshots, etc.
```

## 📚 Recursos Úteis

### Documentação

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [BLoC Pattern](https://bloclibrary.dev/)

### Comunidade

- [Flutter Community](https://flutter.dev/community)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)
- [Discord Flutter](https://discord.gg/flutter)

### Ferramentas

- [Flutter Inspector](https://flutter.dev/docs/development/tools/flutter-inspector)
- [DevTools](https://flutter.dev/docs/development/tools/devtools)
- [Flutter Performance](https://flutter.dev/docs/perf)

## 🏆 Reconhecimento

Contribuidores ativos serão reconhecidos no README do projeto e receberão menções especiais em releases.

### Níveis de Contribuição

- **🥉 Bronze**: 1-5 contribuições
- **🥈 Prata**: 6-15 contribuições
- **🥇 Ouro**: 16+ contribuições
- **💎 Diamante**: Contribuições excepcionais

## 📞 Contato

Se você tiver dúvidas sobre como contribuir:

- **Issues**: [GitHub Issues](https://github.com/chrnotag/wifi_vision/issues)
- **Discussions**: [GitHub Discussions](https://github.com/chrnotag/wifi_vision/discussions)
- **Email**: felippehouse@gmail.com

---

**Obrigado por contribuir para o futuro da tecnologia WiFi! 🌟**
