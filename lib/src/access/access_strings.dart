import 'package:flutter/foundation.dart';

import '../brand/brand.dart';
import 'access_preferences.dart';

/// Copy of the PhoneWeb access screen in pt-BR, en-US and es-ES. Settings ›
/// Themes › Login do PhoneWeb may replace eyebrow, title, subtitle, heroTitle,
/// heroText and supportLabel per language.
class AccessStrings {
  const AccessStrings(this.lang);

  /// Language of the access screen: the one chosen there, else the device's.
  factory AccessStrings.current() {
    final chosen = accessLocale.value?.languageCode;
    final device = PlatformDispatcher.instance.locale.languageCode;
    final code = chosen ?? device;
    return AccessStrings(const {'en', 'es'}.contains(code) ? code : 'pt');
  }

  final String lang;

  /// Language tag of the Themes copy (`pt-BR`, `en-US`, `es-ES`).
  String get locale =>
      const {'pt': 'pt-BR', 'en': 'en-US', 'es': 'es-ES'}[lang]!;

  String t(String key) => _strings[key]?[lang] ?? _strings[key]?['pt'] ?? key;

  /// Themes copy for this language, else the built-in text.
  String text(String key) {
    final texts = phonewebBrand.value?.login['texts'];
    final value = texts is Map && texts[locale] is Map
        ? texts[locale][key]
        : null;
    return value is String && value.trim().isNotEmpty ? value.trim() : t(key);
  }

  @visibleForTesting
  static Iterable<String> get keys => _strings.keys;

  static const Map<String, Map<String, String>> _strings = {
    'language': {'pt': 'Idioma', 'en': 'Language', 'es': 'Idioma'},
    'system': {
      'pt': 'Idioma do sistema',
      'en': 'System language',
      'es': 'Idioma del sistema',
    },
    'eyebrow': {
      'pt': 'Acesso ao telefone',
      'en': 'Phone access',
      'es': 'Acceso al teléfono',
    },
    'title': {
      'pt': 'Entre no PhoneWeb',
      'en': 'Sign in to PhoneWeb',
      'es': 'Entra en PhoneWeb',
    },
    'subtitle': {
      'pt':
          'Use o e-mail do App, o código do Pulse ou o login do portal do cliente.',
      'en': 'Use your App e-mail, Pulse code or customer portal login.',
      'es':
          'Usa el correo de la App, el código de Pulse o el acceso del portal del cliente.',
    },
    'heroTitle': {
      'pt': 'Suas chamadas.\nEm qualquer lugar.',
      'en': 'Your calls.\nAnywhere.',
      'es': 'Tus llamadas.\nEn cualquier lugar.',
    },
    'heroText': {
      'pt':
          'Faça e receba ligações pelo navegador com as linhas da sua empresa.',
      'en': 'Make and take calls in the browser with your company lines.',
      'es':
          'Haz y recibe llamadas en el navegador con las líneas de tu empresa.',
    },
    'supportLabel': {
      'pt': 'Precisa de ajuda? Fale com o suporte',
      'en': 'Need help? Contact support',
      'es': '¿Necesitas ayuda? Contacta con soporte',
    },
    'privacy': {'pt': 'Privacidade', 'en': 'Privacy', 'es': 'Privacidad'},
    'terms': {
      'pt': 'Termos de uso',
      'en': 'Terms of use',
      'es': 'Términos de uso',
    },
    'user': {'pt': 'Usuário', 'en': 'Username', 'es': 'Usuario'},
    'password': {'pt': 'Senha', 'en': 'Password', 'es': 'Contraseña'},
    'showPassword': {
      'pt': 'Mostrar senha',
      'en': 'Show password',
      'es': 'Mostrar contraseña',
    },
    'hidePassword': {
      'pt': 'Ocultar senha',
      'en': 'Hide password',
      'es': 'Ocultar contraseña',
    },
    'server': {
      'pt': 'Servidor MNSCloud',
      'en': 'MNSCloud server',
      'es': 'Servidor MNSCloud',
    },
    'company': {'pt': 'Empresa', 'en': 'Company', 'es': 'Empresa'},
    'chooseCompany': {
      'pt': 'Escolha a empresa e entre de novo.',
      'en': 'Choose the company and sign in again.',
      'es': 'Elija la empresa e inicie sesión de nuevo.',
    },
    'signIn': {'pt': 'Entrar', 'en': 'Sign in', 'es': 'Entrar'},
    'continueWithout': {
      'pt': 'Continuar sem conta',
      'en': 'Continue without an account',
      'es': 'Continuar sin cuenta',
    },
    'continueWithoutHint': {
      'pt':
          'Use contas SIP/WSS de qualquer provedor. Você pode entrar depois em Configurações.',
      'en':
          'Use SIP/WSS accounts from any provider. You can sign in later in Settings.',
      'es':
          'Use cuentas SIP/WSS de cualquier proveedor. Puede entrar después en Configuración.',
    },
    'required': {
      'pt': 'Este campo é obrigatório.',
      'en': 'This field is required.',
      'es': 'Este campo es obligatorio.',
    },
    'forgotPassword': {
      'pt': 'Esqueceu sua senha?',
      'en': 'Forgot your password?',
      'es': '¿Olvidaste tu contraseña?',
    },
    'forgotTitle': {
      'pt': 'Recuperar senha',
      'en': 'Reset your password',
      'es': 'Recuperar contraseña',
    },
    'forgotHelp': {
      'pt':
          'Se você entra com o e-mail do App, recupere a senha pela página do App. '
          'Códigos do Pulse e logins do portal do cliente são gerenciados pela sua empresa: '
          'peça uma nova senha ao responsável pelo seu acesso.',
      'en':
          'If you sign in with your App e-mail, reset the password on the App page. '
          'Pulse codes and customer portal logins are managed by your company: '
          'ask the person in charge of your access for a new password.',
      'es':
          'Si entra con el correo de la App, recupere la contraseña en la página de la App. '
          'Los códigos de Pulse y los accesos del portal del cliente los gestiona su empresa: '
          'pida una nueva contraseña al responsable de su acceso.',
    },
    'appRecovery': {
      'pt': 'Recuperar senha do App',
      'en': 'Reset App password',
      'es': 'Recuperar contraseña de la App',
    },
    'close': {'pt': 'Fechar', 'en': 'Close', 'es': 'Cerrar'},
    'linkError': {
      'pt': 'Não foi possível abrir o link.',
      'en': 'The link could not be opened.',
      'es': 'No se pudo abrir el enlace.',
    },
  };
}
