import '../access/access_strings.dart';

/// UI text of PhoneWeb in the language chosen on the access screen or in Settings
/// (else the device's). Keys are the English text; pt-BR and es-ES translate it.
/// `{name}` placeholders are filled from [args]. Unknown keys show as written.
String tr(String english, [Map<String, Object?> args = const {}]) {
  final lang = AccessStrings.current().lang;
  final row = _translations[english];
  var text = lang == 'en' || row == null ? english : row[lang == 'pt' ? 0 : 1];
  args.forEach((key, value) => text = text.replaceAll('{$key}', '$value'));
  return text;
}

/// English -> [pt-BR, es-ES].
const Map<String, List<String>> _translations = {
  '{queue}: counters unavailable': [
    '{queue}: contadores indisponíveis',
    '{queue}: contadores no disponibles',
  ],
  '{queue}: {waiting} waiting, longest {seconds}s': [
    '{queue}: {waiting} em espera, maior espera {seconds}s',
    '{queue}: {waiting} en espera, espera máxima {seconds}s',
  ],
  "Other": ["Outro", "Otro"],
  "Voicemail": ["Caixa postal", "Buzón de voz"],
  "Wrong number": ["Número incorreto", "Número incorrecto"],
  "No interest": ["Sem interesse", "Sin interés"],
  "Follow up": ["Retornar contato", "Seguimiento"],
  "Resolved": ["Resolvido", "Resuelto"],
  "Save call notes": ["Salvar notas da chamada", "Guardar notas de la llamada"],
  "Call notes": ["Notas da chamada", "Notas de la llamada"],
  "Call outcome": ["Resultado da chamada", "Resultado de la llamada"],
  "Refresh": ["Atualizar", "Actualizar"],
  "Line": ["Linha", "Línea"],
  "Pause": ["Pausar", "Pausar"],
  "Available": ["Disponível", "Disponible"],
  "WRAP_UP": ["Pós-atendimento", "Posllamada"],
  "ON_CALL": ["Em atendimento", "En llamada"],
  "PAUSED": ["Em pausa", "En pausa"],
  "AVAILABLE": ["Disponível", "Disponible"],
  "LOGGED_OUT": ["Fora das filas", "Fuera de las colas"],
  "Wrap-up: {seconds}s": [
    "Pós-atendimento: {seconds}s",
    "Posllamada: {seconds}s",
  ],
  "Next status": ["Próximo estado", "Próximo estado"],
  "Connection unavailable": ["Conexão indisponível", "Conexión no disponible"],
  "Select a pause reason.": [
    "Selecione um motivo de pausa.",
    "Seleccione un motivo de pausa.",
  ],
  "Select a line.": ["Selecione uma linha.", "Seleccione una línea."],
  "Pause reason": ["Motivo da pausa", "Motivo de pausa"],
  "Finish wrap-up": ["Concluir pós-atendimento", "Finalizar posllamada"],
  "Leave queues": ["Sair das filas", "Salir de las colas"],
  "Join queues": ["Entrar nas filas", "Entrar en las colas"],
  "This agent is controlled by another signed-in device.": [
    "Este agente está em uso em outro dispositivo.",
    "Este agente está en uso en otro dispositivo.",
  ],
  'Queue counters unavailable': [
    'Indicadores da fila indisponíveis',
    'Indicadores de la cola no disponibles',
  ],
  'Waiting: {count} · Longest wait: {seconds}s': [
    'Aguardando: {count} · Maior espera: {seconds}s',
    'En espera: {count} · Mayor espera: {seconds}s',
  ],
  "Your phone session expired. Sign in again.": [
    "Sua sessão telefônica expirou. Entre novamente.",
    "Su sesión telefónica venció. Inicie sesión de nuevo.",
  ],
  "The agent state changed. Review the panel and try again.": [
    "O estado do agente mudou. Confira o painel e tente novamente.",
    "El estado del agente cambió. Revise el panel e inténtelo de nuevo.",
  ],
  "The agent or contact is no longer available.": [
    "O agente ou atendimento não está mais disponível.",
    "El agente o la atención ya no está disponible.",
  ],
  "Check the selected line, pause reason and call notes.": [
    "Confira a linha selecionada, o motivo da pausa e as notas do atendimento.",
    "Revise la línea seleccionada, el motivo de pausa y las notas de la atención.",
  ],
  "Unable to update the agent. Try again.": [
    "Não foi possível atualizar o agente. Tente novamente.",
    "No se pudo actualizar el agente. Inténtelo de nuevo.",
  ],
  "Contact center": ["Central de atendimento", "Centro de contacto"],
  '1 WebRTC account configured': [
    '1 conta WebRTC configurada',
    '1 cuenta WebRTC configurada',
  ],
  'Account': ['Conta', 'Cuenta'],
  'Account name': ['Nome da conta', 'Nombre de la cuenta'],
  'Account or domain not found': [
    'Conta ou domínio não encontrado',
    'Cuenta o dominio no encontrado',
  ],
  'Account registered': ['Conta registrada', 'Cuenta registrada'],
  'Account temporarily locked. Try again later.': [
    'Conta bloqueada temporariamente. Tente mais tarde.',
    'Cuenta bloqueada temporalmente. Intente más tarde.',
  ],
  'Accounts': ['Contas', 'Cuentas'],
  'Add WebRTC account': ['Adicionar conta WebRTC', 'Agregar cuenta WebRTC'],
  'Add a WSS provider account to start configuring calls.': [
    'Adicione uma conta de um provedor WSS para começar a fazer chamadas.',
    'Agregue una cuenta de un proveedor WSS para empezar a hacer llamadas.',
  ],
  'Add account': ['Adicionar conta', 'Agregar cuenta'],
  'Add contact': ['Adicionar contato', 'Agregar contacto'],
  'Add contacts to dial faster.': [
    'Adicione contatos para discar mais rápido.',
    'Agregue contactos para marcar más rápido.',
  ],
  'Add to contacts': ['Adicionar aos contatos', 'Agregar a contactos'],
  'Allow WS dev': [
    'Permitir WS de desenvolvimento',
    'Permitir WS de desarrollo',
  ],
  'Already saved as contact': [
    'Já salvo como contato',
    'Ya guardado como contacto',
  ],
  'Answer': ['Atender', 'Contestar'],
  'App MNSCloud member': [
    'Membro do App MNSCloud',
    'Miembro de la App MNSCloud',
  ],
  'Audio and Video': ['Áudio e Vídeo', 'Audio y video'],
  'Audio output': ['Saída de áudio', 'Salida de audio'],
  'Authentication challenge failed': [
    'Falha na autenticação',
    'Falló la autenticación',
  ],
  'Authentication temporarily unavailable': [
    'Autenticação temporariamente indisponível',
    'Autenticación temporalmente no disponible',
  ],
  'Auto register': ['Registrar automaticamente', 'Registrar automáticamente'],
  'Automatic': ['Automático', 'Automático'],
  'Automatic (browser/system)': [
    'Automático pelo navegador/sistema',
    'Automático según el navegador/sistema',
  ],
  'Automatic (system)': [
    'Automático pelo sistema',
    'Automático según el sistema',
  ],
  'Backspace': ['Apagar', 'Borrar'],
  'Call': ['Ligar', 'Llamar'],
  'Call back': ['Retornar ligação', 'Devolver llamada'],
  'Call contact': ['Ligar para o contato', 'Llamar al contacto'],
  'Call history': ['Histórico de chamadas', 'Historial de llamadas'],
  'Call history cleared': [
    'Histórico de chamadas apagado',
    'Historial de llamadas borrado',
  ],
  'Call history entry removed': [
    'Chamada removida do histórico',
    'Llamada eliminada del historial',
  ],
  'Cancel': ['Cancelar', 'Cancelar'],
  'Capture SIP/WebRTC, media, registration and screen events to copy and send for analysis.': [
    'Capture eventos SIP/WebRTC, mídia, registro e ações da tela para copiar e enviar para análise.',
    'Capture eventos SIP/WebRTC, de medios, de registro y de la pantalla para copiarlos y enviarlos a análisis.',
  ],
  'Change the temporary password (in Pulse or the customer portal) before signing in.': [
    'Troque a senha temporária (no Pulse ou no portal do cliente) antes de entrar.',
    'Cambie la contraseña temporal (en Pulse o en el portal del cliente) antes de entrar.',
  ],
  'Clear': ['Limpar', 'Limpiar'],
  'Clear all call history': [
    'Apagar todo o histórico de chamadas',
    'Borrar todo el historial de llamadas',
  ],
  'Clear call history?': [
    'Apagar o histórico de chamadas?',
    '¿Borrar el historial de llamadas?',
  ],
  'Clear history': ['Apagar histórico', 'Borrar historial'],
  'Clear search': ['Limpar busca', 'Limpiar búsqueda'],
  'Close': ['Fechar', 'Cerrar'],
  'Install app': ['Instalar app', 'Instalar app'],
  'In Safari, tap Share and then "Add to Home Screen".': [
    'No Safari, toque em Compartilhar e depois em "Adicionar à Tela de Início".',
    'En Safari, toca Compartir y luego "Agregar a pantalla de inicio".',
  ],
  'Code': ['Código', 'Código'],
  'Codec policy': ['Política de codecs', 'Política de códecs'],
  'Company': ['Empresa', 'Empresa'],
  'Completed': ['Concluída', 'Completada'],
  'Completed calls will appear here.': [
    'As chamadas concluídas aparecerão aqui.',
    'Las llamadas completadas aparecerán aquí.',
  ],
  'Connected': ['Conectado', 'Conectado'],
  'Connecting': ['Conectando', 'Conectando'],
  'Contact synced from the device': [
    'Contato sincronizado do dispositivo',
    'Contacto sincronizado del dispositivo',
  ],
  'Contacts': ['Contatos', 'Contactos'],
  'Copy': ['Copiar', 'Copiar'],
  'Could not reach the MNSCloud server.': [
    'Não foi possível acessar o servidor MNSCloud.',
    'No se pudo acceder al servidor MNSCloud.',
  ],
  'Could not sign in. Try again.': [
    'Não foi possível entrar. Tente novamente.',
    'No se pudo entrar. Intente de nuevo.',
  ],
  'Customer (portal login)': [
    'Cliente (login do portal)',
    'Cliente (acceso del portal)',
  ],
  'Debug copied': ['Debug copiado', 'Depuración copiada'],
  'Decline': ['Recusar', 'Rechazar'],
  'Dedicated': ['Dedicada', 'Dedicada'],
  'Diagnostic': ['Diagnóstico', 'Diagnóstico'],
  'Diagnostic copied': ['Diagnóstico copiado', 'Diagnóstico copiado'],
  'Dialer': ['Discador', 'Marcador'],
  'Disable': ['Desativar', 'Desactivar'],
  'Disconnect account': ['Desconectar conta', 'Desconectar cuenta'],
  'Display name': ['Nome de exibição', 'Nombre para mostrar'],
  'Domain': ['Domínio', 'Dominio'],
  'E-mail, Pulse code or portal login': [
    'E-mail, código do Pulse ou login do portal',
    'Correo, código de Pulse o acceso del portal',
  ],
  'Edit WebRTC account': ['Editar conta WebRTC', 'Editar cuenta WebRTC'],
  'Edit account': ['Editar conta', 'Editar cuenta'],
  'Edit contact': ['Editar contato', 'Editar contacto'],
  'Employee (Pulse login)': [
    'Funcionário (login do Pulse)',
    'Empleado (acceso de Pulse)',
  ],
  'Empty history': ['Histórico vazio', 'Historial vacío'],
  'Enable': ['Ativar', 'Activar'],
  'Enable WS dev for insecure transport': [
    'Ative o WS de desenvolvimento para transporte inseguro',
    'Active el WS de desarrollo para transporte inseguro',
  ],
  'Enable detailed debug': [
    'Ativar debug detalhado',
    'Activar depuración detallada',
  ],
  'Enabled': ['Ativa', 'Activa'],
  'Enter number': ['Digite o número', 'Ingrese el número'],
  'Enter the MNSCloud server address (https://...).': [
    'Informe o endereço do servidor MNSCloud (https://...).',
    'Ingrese la dirección del servidor MNSCloud (https://...).',
  ],
  'Failed': ['Falhou', 'Falló'],
  'Free extension (reserved)': [
    'Ramal livre (reservado)',
    'Extensión libre (reservada)',
  ],
  'Free extensions': ['Ramais livres', 'Extensiones libres'],
  'G.711 only': ['Somente G.711', 'Solo G.711'],
  'Hang up': ['Desligar', 'Colgar'],
  'Hide password': ['Ocultar senha', 'Ocultar contraseña'],
  'History': ['Histórico', 'Historial'],
  'Hold': ['Em espera', 'En espera'],
  'Important update': ['Atualização importante', 'Actualización importante'],
  'Incoming': ['Recebida', 'Entrante'],
  'Interface': ['Interface', 'Interfaz'],
  'Invalid username or password.': [
    'Usuário ou senha inválidos.',
    'Usuario o contraseña no válidos.',
  ],
  'Language': ['Idioma', 'Idioma'],
  'Language of the screens; follows the device when automatic.': [
    'Idioma das telas; segue o dispositivo quando automático.',
    'Idioma de las pantallas; sigue al dispositivo cuando es automático.',
  ],
  'Later': ['Depois', 'Después'],
  'Local diagnostics for SIP/WebRTC, media and screen actions.': [
    'Diagnóstico local para SIP/WebRTC, mídia e ações da tela.',
    'Diagnóstico local de SIP/WebRTC, medios y acciones de la pantalla.',
  ],
  'Local media settings of the softphone.': [
    'Configurações locais de mídia do softphone.',
    'Configuración local de medios del softphone.',
  ],
  'MNSCloud account': ['Conta MNSCloud', 'Cuenta MNSCloud'],
  'MNSCloud server': ['Servidor MNSCloud', 'Servidor MNSCloud'],
  'Managed line of your company in MNSCloud: it cannot be edited or removed here.': [
    'Linha gerenciada pela sua empresa na MNSCloud: não pode ser editada nem excluída aqui.',
    'Línea gestionada por su empresa en MNSCloud: no se puede editar ni eliminar aquí.',
  ],
  'Messages': ['Mensagens', 'Mensajes'],
  'Microphone': ['Microfone', 'Micrófono'],
  'Missed': ['Perdida', 'Perdida'],
  'Mute': ['Silenciar', 'Silenciar'],
  'My lines': ['Minhas linhas', 'Mis líneas'],
  'Name': ['Nome', 'Nombre'],
  'New version available': [
    'Nova versão disponível',
    'Nueva versión disponible',
  ],
  'No': ['Não', 'No'],
  'No WebRTC accounts': ['Nenhuma conta WebRTC', 'Ninguna cuenta WebRTC'],
  'No account': ['Nenhuma conta', 'Ninguna cuenta'],
  'No accounts found': [
    'Nenhuma conta encontrada',
    'Ninguna cuenta encontrada',
  ],
  'No accounts match your search.': [
    'Nenhuma conta corresponde à busca.',
    'Ninguna cuenta coincide con la búsqueda.',
  ],
  'No call found': ['Nenhuma chamada encontrada', 'Ninguna llamada encontrada'],
  'No calls found': [
    'Nenhuma chamada encontrada',
    'Ninguna llamada encontrada',
  ],
  'No calls yet': ['Nenhuma chamada ainda', 'Aún no hay llamadas'],
  'No contact found': [
    'Nenhum contato encontrado',
    'Ningún contacto encontrado',
  ],
  'No contacts': ['Nenhum contato', 'Ningún contacto'],
  'No contacts found': [
    'Nenhum contato encontrado',
    'Ningún contacto encontrado',
  ],
  'No contacts yet': ['Nenhum contato ainda', 'Aún no hay contactos'],
  'No line assigned. Take a free extension below or ask the administrator.': [
    'Nenhuma linha atribuída. Pegue um ramal livre abaixo ou peça ao administrador.',
    'Ninguna línea asignada. Tome una extensión libre abajo o pida al administrador.',
  ],
  'No message found': [
    'Nenhuma mensagem encontrada',
    'Ningún mensaje encontrado',
  ],
  'No messages yet': ['Nenhuma mensagem ainda', 'Aún no hay mensajes'],
  'No service': ['Sem serviço', 'Sin servicio'],
  'OPUS only': ['Somente OPUS', 'Solo OPUS'],
  'Observed': ['Observado', 'Observado'],
  'Offline': ['Sem serviço', 'Sin servicio'],
  'Optional. Sign in with the login you already use in MNSCloud: App e-mail, Pulse code or customer portal login. Without signing in, PhoneWeb keeps working with manual accounts from any SIP/WSS provider.': [
    'Opcional. Entre com o login que você já usa na MNSCloud: e-mail do App, código do Pulse ou login do portal do cliente. Sem entrar, o PhoneWeb continua funcionando com contas manuais de qualquer provedor SIP/WSS.',
    'Opcional. Entre con el acceso que ya usa en MNSCloud: correo de la App, código de Pulse o acceso del portal del cliente. Sin entrar, PhoneWeb sigue funcionando con cuentas manuales de cualquier proveedor SIP/WSS.',
  ],
  'Outgoing': ['Realizada', 'Saliente'],
  'Password': ['Senha', 'Contraseña'],
  'Phone': ['Telefone', 'Teléfono'],
  'Phone number': ['Número de telefone', 'Número de teléfono'],
  'PhoneWeb could not keep the WebSocket transport open. Check the WSS URL, TLS certificate, proxy, firewall, or server availability.': [
    'O PhoneWeb não conseguiu manter o transporte WebSocket aberto. Verifique a URL WSS, o certificado TLS, o proxy, o firewall ou a disponibilidade do servidor.',
    'PhoneWeb no pudo mantener abierto el transporte WebSocket. Verifique la URL WSS, el certificado TLS, el proxy, el firewall o la disponibilidad del servidor.',
  ],
  'PhoneWeb is connecting to the WSS server and sending SIP REGISTER.': [
    'O PhoneWeb está se conectando ao servidor WSS e enviando o SIP REGISTER.',
    'PhoneWeb se está conectando al servidor WSS y enviando el SIP REGISTER.',
  ],
  'PhoneWeb is not included in the company subscription.': [
    'O PhoneWeb não está incluído na assinatura da empresa.',
    'PhoneWeb no está incluido en la suscripción de la empresa.',
  ],
  'PhoneWeb was updated with improvements and fixes. Update when convenient; your accounts and history stay saved.': [
    'O PhoneWeb foi atualizado com melhorias e correções. Atualize quando for conveniente; suas contas e o histórico ficam salvos.',
    'PhoneWeb se actualizó con mejoras y correcciones. Actualice cuando le convenga; sus cuentas y el historial quedan guardados.',
  ],
  'Placed and received calls will appear here.': [
    'As chamadas realizadas e recebidas aparecerão aqui.',
    'Las llamadas realizadas y recibidas aparecerán aquí.',
  ],
  'Prefers OPUS and allows PCMU/PCMA fallback for SIP trunks.': [
    'Prefere OPUS e permite PCMU/PCMA como alternativa para troncos SIP.',
    'Prefiere OPUS y permite PCMU/PCMA como alternativa para troncales SIP.',
  ],
  'Ready': ['Pronto', 'Listo'],
  'Reason': ['Motivo', 'Motivo'],
  'Refresh lines': ['Atualizar linhas', 'Actualizar líneas'],
  'Register account': ['Registrar conta', 'Registrar cuenta'],
  'Registered': ['Registrado', 'Registrado'],
  'Registering': ['Registrando', 'Registrando'],
  'Registering account': ['Registrando a conta', 'Registrando la cuenta'],
  'Registration details': ['Detalhes do registro', 'Detalles del registro'],
  'Registration diagnostic': [
    'Diagnóstico do registro',
    'Diagnóstico del registro',
  ],
  'Registration failed': ['Falha no registro', 'Falló el registro'],
  'Registration forbidden': ['Registro proibido', 'Registro prohibido'],
  'Registration interrupted': [
    'Registro interrompido',
    'Registro interrumpido',
  ],
  'Registration interval too brief': [
    'Intervalo de registro muito curto',
    'Intervalo de registro demasiado corto',
  ],
  'Registration stopped': ['Registro parado', 'Registro detenido'],
  'Registration storage unavailable': [
    'Armazenamento de registro indisponível',
    'Almacenamiento de registro no disponible',
  ],
  'Registration timed out': ['O registro expirou', 'El registro expiró'],
  'Release': ['Liberar', 'Liberar'],
  'Remind me later': ['Lembrar mais tarde', 'Recordar más tarde'],
  'Remove account': ['Remover conta', 'Eliminar cuenta'],
  'Remove from history': ['Remover do histórico', 'Eliminar del historial'],
  'Required': ['Obrigatório', 'Obligatorio'],
  'Required field': ['Campo obrigatório', 'Campo obligatorio'],
  'Reserved for future video calls.': [
    'Reservado para chamadas futuras com vídeo.',
    'Reservado para futuras llamadas con video.',
  ],
  'Resume': ['Retomar', 'Reanudar'],
  'Retrying': ['Tentando novamente', 'Reintentando'],
  'SIP Domain': ['Domínio SIP', 'Dominio SIP'],
  'SIP Password': ['Senha SIP', 'Contraseña SIP'],
  'SIP server error': ['Erro no servidor SIP', 'Error del servidor SIP'],
  'SIP user': ['Usuário SIP', 'Usuario SIP'],
  'STUN server': ['Servidor STUN', 'Servidor STUN'],
  'Save': ['Salvar', 'Guardar'],
  'Search accounts': ['Buscar contas', 'Buscar cuentas'],
  'Search by account name, SIP user, domain, WSS or status.': [
    'Busque por nome da conta, usuário SIP, domínio, WSS ou status.',
    'Busque por nombre de cuenta, usuario SIP, dominio, WSS o estado.',
  ],
  'Search by name, company or number.': [
    'Busque por nome, empresa ou número.',
    'Busque por nombre, empresa o número.',
  ],
  'Search by number, account, status or SIP diagnostic.': [
    'Busque por número, conta, status ou diagnóstico SIP.',
    'Busque por número, cuenta, estado o diagnóstico SIP.',
  ],
  'Search call history': ['Buscar no histórico', 'Buscar en el historial'],
  'Search contact': ['Buscar contato', 'Buscar contacto'],
  'Search contacts': ['Buscar contatos', 'Buscar contactos'],
  'Search history': ['Buscar histórico', 'Buscar historial'],
  'Search messages': ['Pesquisar mensagens', 'Buscar mensajes'],
  'Select or add an account before placing calls.': [
    'Selecione ou adicione uma conta antes de ligar.',
    'Seleccione o agregue una cuenta antes de llamar.',
  ],
  'Server did not respond': [
    'O servidor não respondeu',
    'El servidor no respondió',
  ],
  'Server temporarily unavailable': [
    'Servidor temporariamente indisponível',
    'Servidor temporalmente no disponible',
  ],
  'Session valid until {date}': [
    'Sessão válida até {date}',
    'Sesión válida hasta {date}',
  ],
  'Settings': ['Configurações', 'Configuración'],
  'Shared': ['Compartilhada', 'Compartida'],
  'Show password': ['Mostrar senha', 'Mostrar contraseña'],
  'Sign in': ['Entrar', 'Entrar'],
  'Sign in to the MNSCloud App and open PhoneWeb from it.': [
    'Entre no App MNSCloud e abra o PhoneWeb a partir dele.',
    'Entre en la App MNSCloud y abra PhoneWeb desde ella.',
  ],
  'Sign out': ['Sair', 'Salir'],
  'Status': ['Status', 'Estado'],
  'Sync address book': ['Sincronizar agenda', 'Sincronizar agenda'],
  'Sync contacts': ['Sincronizar contatos', 'Sincronizar contactos'],
  'Sync device address book': [
    'Sincronizar agenda do dispositivo',
    'Sincronizar agenda del dispositivo',
  ],
  'Sync device contacts': [
    'Sincronizar contatos do dispositivo',
    'Sincronizar contactos del dispositivo',
  ],
  'Sync the device address book or add a local contact.': [
    'Sincronize a agenda do dispositivo ou adicione um contato local.',
    'Sincronice la agenda del dispositivo o agregue un contacto local.',
  ],
  'TURN server': ['Servidor TURN', 'Servidor TURN'],
  'Take': ['Pegar', 'Tomar'],
  'The SIP registration was interrupted unexpectedly. PhoneWeb is waiting for the WebSocket/SIP stack to reconnect or refresh the registration.': [
    'O registro SIP foi interrompido inesperadamente. O PhoneWeb está aguardando a pilha WebSocket/SIP reconectar ou renovar o registro.',
    'El registro SIP se interrumpió inesperadamente. PhoneWeb espera que la pila WebSocket/SIP se reconecte o renueve el registro.',
  ],
  'The SIP server accepted the registration.': [
    'O servidor SIP aceitou o registro.',
    'El servidor SIP aceptó el registro.',
  ],
  'The SIP server authenticated the account but could not save the registration contact. PhoneWeb will retry automatically; check the softswitch location storage/runtime logs.': [
    'O servidor SIP autenticou a conta, mas não conseguiu salvar o contato do registro. O PhoneWeb tentará de novo automaticamente; verifique o armazenamento de localização e os logs do softswitch.',
    'El servidor SIP autenticó la cuenta, pero no pudo guardar el contacto del registro. PhoneWeb reintentará automáticamente; revise el almacenamiento de ubicación y los registros del softswitch.',
  ],
  'The SIP server could not validate the account with the realtime authentication service right now. PhoneWeb will retry automatically; check the softswitch/API runtime path if this persists.': [
    'O servidor SIP não conseguiu validar a conta no serviço de autenticação em tempo real agora. O PhoneWeb tentará de novo automaticamente; se persistir, verifique o caminho softswitch/API.',
    'El servidor SIP no pudo validar la cuenta con el servicio de autenticación en tiempo real ahora. PhoneWeb reintentará automáticamente; si persiste, revise la ruta softswitch/API.',
  ],
  'The SIP server did not find this user or domain. Verify the SIP username and domain configured in the account.': [
    'O servidor SIP não encontrou este usuário ou domínio. Verifique o usuário SIP e o domínio configurados na conta.',
    'El servidor SIP no encontró este usuario o dominio. Verifique el usuario SIP y el dominio configurados en la cuenta.',
  ],
  'The SIP server or an upstream component returned an error. This is usually temporary and should be checked on the server side.': [
    'O servidor SIP ou um componente anterior retornou um erro. Geralmente é temporário e deve ser verificado no servidor.',
    'El servidor SIP o un componente previo devolvió un error. Suele ser temporal y debe revisarse en el servidor.',
  ],
  'The SIP server rejected or interrupted the registration. Check the account data and server logs if the failure persists.': [
    'O servidor SIP recusou ou interrompeu o registro. Se a falha persistir, verifique os dados da conta e os logs do servidor.',
    'El servidor SIP rechazó o interrumpió el registro. Si la falla persiste, revise los datos de la cuenta y los registros del servidor.',
  ],
  'The SIP service temporarily refused the registration. Retrying may succeed when the server becomes available.': [
    'O serviço SIP recusou o registro temporariamente. Uma nova tentativa pode funcionar quando o servidor voltar.',
    'El servicio SIP rechazó el registro temporalmente. Reintentar puede funcionar cuando el servidor esté disponible.',
  ],
  'The WebSocket transport changed state while PhoneWeb was registering.': [
    'O transporte WebSocket mudou de estado enquanto o PhoneWeb registrava a conta.',
    'El transporte WebSocket cambió de estado mientras PhoneWeb registraba la cuenta.',
  ],
  'The WebSocket transport closed before the account completed registration. Check connectivity, WSS URL, TLS certificate, firewall, or server availability.': [
    'O transporte WebSocket fechou antes de a conta concluir o registro. Verifique a conectividade, a URL WSS, o certificado TLS, o firewall ou a disponibilidade do servidor.',
    'El transporte WebSocket se cerró antes de que la cuenta completara el registro. Verifique la conectividad, la URL WSS, el certificado TLS, el firewall o la disponibilidad del servidor.',
  ],
  'The account is not currently registered.': [
    'A conta não está registrada no momento.',
    'La cuenta no está registrada en este momento.',
  ],
  'The registration timed out. This is usually temporary; check WSS connectivity, server load, firewall, and routing.': [
    'O registro expirou. Geralmente é temporário; verifique a conectividade WSS, a carga do servidor, o firewall e o roteamento.',
    'El registro expiró. Suele ser temporal; verifique la conectividad WSS, la carga del servidor, el firewall y el enrutamiento.',
  ],
  'The server did not answer in time. This is usually temporary; PhoneWeb may register successfully on a later attempt.': [
    'O servidor não respondeu a tempo. Geralmente é temporário; o PhoneWeb pode registrar numa próxima tentativa.',
    'El servidor no respondió a tiempo. Suele ser temporal; PhoneWeb puede registrarse en un próximo intento.',
  ],
  'The server rejected this account. Verify that the subscriber is active, authorized, and allowed to register from WebRTC.': [
    'O servidor recusou esta conta. Verifique se o assinante está ativo, autorizado e liberado para registrar via WebRTC.',
    'El servidor rechazó esta cuenta. Verifique que el suscriptor esté activo, autorizado y habilitado para registrarse por WebRTC.',
  ],
  'The server requested a longer registration interval. PhoneWeb should retry using the server minimum interval.': [
    'O servidor pediu um intervalo de registro maior. O PhoneWeb deve tentar de novo com o intervalo mínimo do servidor.',
    'El servidor pidió un intervalo de registro mayor. PhoneWeb debe reintentar con el intervalo mínimo del servidor.',
  ],
  'The server requested authentication but the REGISTER did not complete. Verify username, password, SIP domain, and server realm.': [
    'O servidor pediu autenticação, mas o REGISTER não foi concluído. Verifique usuário, senha, domínio SIP e realm do servidor.',
    'El servidor pidió autenticación, pero el REGISTER no se completó. Verifique usuario, contraseña, dominio SIP y realm del servidor.',
  ],
  'The sign-in link expired. Open PhoneWeb from the App again.': [
    'O link de entrada expirou. Abra o PhoneWeb pelo App novamente.',
    'El enlace de acceso expiró. Abra PhoneWeb desde la App de nuevo.',
  ],
  'Theme': ['Tema', 'Tema'],
  'This line has no WebRTC access yet. Contact the administrator.': [
    'Esta linha ainda não tem acesso WebRTC. Fale com o administrador.',
    'Esta línea aún no tiene acceso WebRTC. Contacte al administrador.',
  ],
  'This line was taken by someone else or you already have too many lines.': [
    'Esta linha foi pega por outra pessoa ou você já tem linhas demais.',
    'Otra persona tomó esta línea o usted ya tiene demasiadas líneas.',
  ],
  'This login has PhoneWeb in more than one company. Choose one.': [
    'Este login tem PhoneWeb em mais de uma empresa. Escolha uma.',
    'Este acceso tiene PhoneWeb en más de una empresa. Elija una.',
  ],
  'This login has no PhoneWeb access. Contact the administrator.': [
    'Este login não tem acesso ao PhoneWeb. Fale com o administrador.',
    'Este acceso no tiene PhoneWeb. Contacte al administrador.',
  ],
  'This version fixes an important problem. Update as soon as possible; your accounts and history stay saved.': [
    'Esta versão corrige um problema importante. Atualize assim que possível; suas contas e o histórico ficam salvos.',
    'Esta versión corrige un problema importante. Actualice lo antes posible; sus cuentas y el historial quedan guardados.',
  ],
  'This will remove {n} local call history entries from this device.': [
    'Isso vai remover {n} chamadas do histórico local deste dispositivo.',
    'Esto eliminará {n} llamadas del historial local de este dispositivo.',
  ],
  'Try searching by name, company or number.': [
    'Tente buscar por nome, empresa ou número.',
    'Intente buscar por nombre, empresa o número.',
  ],
  'Try searching by number, account, status or SIP.': [
    'Tente buscar por número, conta, status ou SIP.',
    'Intente buscar por número, cuenta, estado o SIP.',
  ],
  'Unknown': ['Desconhecido', 'Desconocido'],
  'Unmute': ['Ativar som', 'Activar sonido'],
  'Update now': ['Atualizar agora', 'Actualizar ahora'],
  'Use a WSS URL': ['Use uma URL WSS', 'Use una URL WSS'],
  'Username': ['Usuário', 'Usuario'],
  'Uses OPUS only. Best for WebRTC-to-WebRTC calls.': [
    'Usa somente OPUS. Melhor para chamadas WebRTC para WebRTC.',
    'Usa solo OPUS. Mejor para llamadas WebRTC a WebRTC.',
  ],
  'Uses PCMU/PCMA only for legacy SIP trunk compatibility.': [
    'Usa somente PCMU/PCMA, para compatibilidade com troncos SIP antigos.',
    'Usa solo PCMU/PCMA, para compatibilidad con troncales SIP antiguas.',
  ],
  'Uses the default device allowed by the browser.': [
    'Usa o dispositivo padrão permitido pelo navegador.',
    'Usa el dispositivo predeterminado permitido por el navegador.',
  ],
  'Uses the default system/browser output.': [
    'Usa a saída padrão do sistema/navegador.',
    'Usa la salida predeterminada del sistema/navegador.',
  ],
  'Version': ['Versão', 'Versión'],
  'Visual preferences of PhoneWeb.': [
    'Preferências visuais do PhoneWeb.',
    'Preferencias visuales de PhoneWeb.',
  ],
  'Voicemail and messages will be available here.': [
    'Correio de voz e mensagens ficarão disponíveis aqui.',
    'El buzón de voz y los mensajes estarán disponibles aquí.',
  ],
  'WSS server': ['Servidor WSS', 'Servidor WSS'],
  'WebSocket connection error': [
    'Erro na conexão WebSocket',
    'Error de conexión WebSocket',
  ],
  'WebSocket disconnected': [
    'WebSocket desconectado',
    'WebSocket desconectado',
  ],
  'When messages are synced, the search will find them by contact, number, subject and content.': [
    'Quando mensagens forem sincronizadas, a busca localizará por contato, número, assunto e conteúdo.',
    'Cuando se sincronicen los mensajes, la búsqueda los encontrará por contacto, número, asunto y contenido.',
  ],
  'Yes': ['Sim', 'Sí'],
  '{kind} · main': ['{kind} · principal', '{kind} · principal'],
  '{name} added': ['{name} adicionada', '{name} agregada'],
  '{name} removed': ['{name} removida', '{name} eliminada'],
  '{name} saved': ['{name} salvo', '{name} guardado'],
  '{name} updated': ['{name} atualizada', '{name} actualizada'],
  '{n} WebRTC accounts configured': [
    '{n} contas WebRTC configuradas',
    '{n} cuentas WebRTC configuradas',
  ],
  '{n} event(s) captured. The buffer keeps the last 600 events.': [
    '{n} evento(s) capturado(s). O buffer mantém os últimos 600 eventos.',
    '{n} evento(s) capturado(s). El búfer conserva los últimos 600 eventos.',
  ],
  '{source} · no WebRTC access': [
    '{source} · sem acesso WebRTC',
    '{source} · sin acceso WebRTC',
  ],
  '{summary} · retrying': [
    '{summary} · tentando novamente',
    '{summary} · reintentando',
  ],
};
