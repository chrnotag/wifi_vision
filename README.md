# 🌐 WiFi Vision - Radar WiFi para Detecção de Objetos

[![Flutter](https://img.shields.io/badge/Flutter-3.8.1+-blue.svg)](https://flutter.dev/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android-blue.svg)](https://developer.android.com/)
[![Status](https://img.shields.io/badge/Status-Prototype-orange.svg)](https://github.com/chrnotag/wifi_vision)

> **Transformando smartphones em radares WiFi para detecção de objetos através de paredes**

## 🎯 Visão Geral

O **WiFi Vision** é um projeto revolucionário que transforma dispositivos móveis em sistemas de radar utilizando sinais WiFi para detectar e mapear objetos em ambientes 2D e 3D. Inspirado na tecnologia de sonar submarino, o aplicativo utiliza o rebatimento de ondas WiFi para calcular a posição de objetos ao redor, criando uma "visão" através de obstáculos.

### 🚀 Objetivos Principais

- **Equipes de Resgate**: Facilitar operações em desabamentos, desmoronamentos e soterramentos
- **Aplicação Policial**: Auxiliar agentes a "ver" através de paredes durante operações
- **Segurança Civil**: Detecção de objetos e pessoas em situações de emergência
- **Mapeamento de Ambiente**: Criação de mapas 3D de espaços fechados

## 🔬 Como Funciona

### Princípio de Funcionamento

O sistema funciona através da análise de sinais WiFi que são refletidos por objetos no ambiente:

1. **Emissão de Sinais**: O dispositivo emite e recebe sinais WiFi
2. **Análise de Rebatimento**: Processa as variações de intensidade do sinal
3. **Algoritmos de Detecção**: Utiliza algoritmos avançados para identificar objetos
4. **Mapeamento 3D**: Gera representações visuais dos objetos detectados

### Tecnologias Utilizadas

- **Flutter**: Interface multiplataforma
- **Algoritmos de Processamento de Sinal**: Marching Squares, RDP Simplifier
- **Visualização 3D**: Model Viewer Plus
- **Sensores de Dispositivo**: Magnetômetro, GPS, WiFi
- **Machine Learning**: Processamento de dados em tempo real

## 🛠️ Funcionalidades

### 🎮 Modo Demo (Atual)
- Simulação de detecção de objetos WiFi
- Visualização em tempo real do mapeamento
- Interface intuitiva com controles de threshold
- Mapeamento 2D com células de 10cm x 10cm

### 📡 Modo WiFi Real (Em Desenvolvimento)
- Escaneamento de redes WiFi disponíveis
- Análise de intensidade de sinal (RSSI)
- Detecção de objetos através de interferência de sinal
- Mapeamento baseado em dados reais

### 🌍 Visualizações
- **Mapa 2D**: Representação topográfica com heatmap
- **Sonar WiFi**: Interface visual similar a radar submarino
- **Visualização 3D**: Modelos tridimensionais dos objetos detectados
- **Bússola**: Orientação em tempo real

### 📊 Análise de Dados
- Cálculo de área dos objetos detectados
- Contagem de vértices e complexidade geométrica
- Estatísticas de detecção em tempo real
- Exportação de dados para análise posterior

## 🚧 Status do Projeto

### ✅ Implementado
- [x] Interface principal com Flutter
- [x] Sistema de simulação de detecção
- [x] Algoritmos de processamento de sinal
- [x] Visualização 2D com heatmap
- [x] Sistema de sonar visual
- [x] Visualização 3D básica
- [x] Arquitetura BLoC para gerenciamento de estado

### 🔄 Em Desenvolvimento
- [ ] Integração com hardware WiFi real
- [ ] Calibração de sensores
- [ ] Otimização de algoritmos
- [ ] Interface de usuário avançada
- [ ] Sistema de calibração automática

### 📋 Planejado
- [ ] Aplicação para equipes de resgate
- [ ] Versão para aplicações policiais
- [ ] API para integração com outros sistemas
- [ ] Versão desktop/Web
- [ ] Suporte a múltiplos dispositivos

## 🏗️ Arquitetura Técnica

### Estrutura do Projeto
```
lib/
├── main.dart              # Aplicação principal e lógica de negócio
├── wifi_service.dart      # Serviços de WiFi e processamento de sinal
├── three_d_view.dart      # Visualização 3D e renderização
└── models/                # Modelos de dados e entidades
```

### Dependências Principais
- **flutter_bloc**: Gerenciamento de estado
- **vector_math**: Cálculos matemáticos 3D
- **wifi_iot**: Acesso a funcionalidades WiFi
- **model_viewer_plus**: Renderização 3D
- **permission_handler**: Gerenciamento de permissões

### Algoritmos Implementados
- **Marching Squares**: Detecção de contornos
- **RDP Simplifier**: Simplificação de polígonos
- **Triangulação Ear-Clipping**: Geração de malhas 3D
- **Suavização Gaussiana**: Processamento de sinal

## 📱 Como Usar

### Pré-requisitos
- Android 6.0+ (API 23+)
- Permissões de localização e WiFi
- Dispositivo com sensores de orientação

### Instalação
1. Clone o repositório
2. Execute `flutter pub get`
3. Conecte um dispositivo Android
4. Execute `flutter run`

### Uso Básico
1. **Iniciar Aplicação**: Abra o app e conceda permissões
2. **Modo Demo**: Ative o modo de demonstração
3. **Varrer Ambiente**: Use o botão "Varrer" para simular detecção
4. **Ajustar Threshold**: Configure a sensibilidade de detecção
5. **Visualizar Resultados**: Explore as diferentes visualizações

## 🔮 Roadmap

### Fase 1: Protótipo (Atual)
- ✅ Sistema básico de simulação
- ✅ Interface de usuário
- ✅ Algoritmos fundamentais

### Fase 2: Integração Real (Próximos 6 meses)
- 🔄 Hardware WiFi especializado
- 🔄 Calibração de sensores
- 🔄 Testes em campo

### Fase 3: Produção (12-18 meses)
- 📋 Aplicações específicas para resgate
- 📋 Versão para aplicações policiais
- 📋 Certificações de segurança

### Fase 4: Expansão (24+ meses)
- 📋 API pública
- 📋 Suporte multiplataforma
- 📋 Integração com sistemas existentes

## 🤝 Contribuição

### Como Contribuir
1. **Fork** o projeto
2. Crie uma **branch** para sua feature
3. **Commit** suas mudanças
4. **Push** para a branch
5. Abra um **Pull Request**

### Áreas de Contribuição
- **Algoritmos**: Melhorias nos algoritmos de detecção
- **Interface**: Design e experiência do usuário
- **Hardware**: Integração com novos sensores
- **Documentação**: Melhorias na documentação
- **Testes**: Cobertura de testes e validação

### Padrões de Código
- Siga as convenções do Flutter
- Use BLoC para gerenciamento de estado
- Documente funções complexas
- Mantenha testes atualizados

## 📄 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

## 👨‍💻 Autor

**Felippe Pinheiro de Almeida**

- **GitHub**: [@chrnotag](https://github.com/chrnotag)
- **LinkedIn**: [Felippe Pinheiro de Almeida](https://www.linkedin.com/in/felippe-pinheiro-de-almeida-739383184/)
- **Email**: felippehouse@gmail.com

## 🙏 Agradecimentos

- Comunidade Flutter
- Pesquisadores em processamento de sinal
- Equipes de resgate e segurança pública
- Contribuidores do projeto

## 📚 Referências

### Artigos Científicos
- "WiFi-based Object Detection and Localization"
- "Through-Wall Imaging Using WiFi Signals"
- "Machine Learning for RF Signal Processing"

### Tecnologias Relacionadas
- [WiFi Sensing](https://wifi-sensing.org/)
- [RF Signal Processing](https://ieeexplore.ieee.org/)
- [Flutter Development](https://flutter.dev/)

## 📞 Contato

Para dúvidas, sugestões ou colaborações:

- **Issues**: [GitHub Issues](https://github.com/chrnotag/wifi_vision/issues)
- **Discussions**: [GitHub Discussions](https://github.com/chrnotag/wifi_vision/discussions)
- **Email**: felippehouse@gmail.com

---

<div align="center">

**🌟 Transformando a visão do futuro através da tecnologia WiFi 🌟**

*Este projeto representa um passo revolucionário na detecção de objetos através de obstáculos, com aplicações que podem salvar vidas e melhorar a segurança pública.*

</div>
