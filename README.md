# Litly Mobile 📚

Litly é uma rede social dedicada a amantes de livros e leitura. A aplicação permite aos utilizadores partilhar o que estão a ler, descobrir novas obras, interagir com outros leitores através de publicações e conversar em tempo real.

## 🚀 Funcionalidades

- **Autenticação:** Registo e Login seguros utilizando o Firebase Authentication.
- **Feed Principal (Home):** Visualização de publicações da comunidade em tempo real.
- **Explorar:** Pesquise por livros, autores ou outros utilizadores da plataforma.
- **Criar Publicação:** Partilhe as suas leituras atuais, opiniões e pensamentos com a comunidade.
- **Chat:** Converse em tempo real com outros utilizadores.
- **Perfil do Utilizador:** Personalize a sua biografia, veja as suas estatísticas (seguidores, a seguir) e aceda ao histórico das suas publicações.

## 🛠️ Tecnologias Utilizadas

- **Frontend:** [Flutter](https://flutter.dev/) (Dart)
- **Backend/Serviços:** [Firebase](https://firebase.google.com/)
  - Firebase Authentication (Gestão de utilizadores)
  - Cloud Firestore (Base de dados em tempo real para posts, utilizadores e mensagens)

## 📦 Estrutura do Projeto

A lógica principal da aplicação encontra-se no diretório `lib/`, onde o `main.dart` atua como ponto de entrada, configurando o tema e as rotas de navegação (Bottom Navigation Bar) para os diferentes ecrãs:
- `HomeScreen`: Feed de publicações.
- `ExploreScreen`: Grelha de descoberta e pesquisa.
- `CreatePostScreen`: Criação de novo conteúdo.
- `ChatListScreen` e `ChatScreen`: Lista de conversas e mensagens privadas.
- `ProfileScreen` e `EditProfileScreen`: Gestão e visualização do perfil.

## ⚙️ Como Executar o Projeto

### Pré-requisitos
- [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado.
- Conta e projeto configurado no [Firebase](https://console.firebase.google.com/).
- Dispositivo físico ou emulador (Android/iOS) configurado.

### Passos

1. Clone o repositório:
   ```bash
   git clone [https://github.com/jul1asouz4/litlyapp.git](https://github.com/jul1asouz4/litlyapp.git)
