/// SSH connection configuration with optional panel API fields.
class SshConfig {
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final String? passphrase; // for encrypted PEM keys

  // Optional panel API
  final String? panel1PanelPort;
  final String? panel1PanelApiKey;
  final String? panelBtPort;
  final String? panelBtApiKey;

  const SshConfig({
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKey,
    this.passphrase,
    this.panel1PanelPort,
    this.panel1PanelApiKey,
    this.panelBtPort,
    this.panelBtApiKey,
  });

  bool get hasPanel1Panel =>
      panel1PanelPort != null && panel1PanelPort!.isNotEmpty &&
      panel1PanelApiKey != null && panel1PanelApiKey!.isNotEmpty;

  bool get hasPanelBt =>
      panelBtPort != null && panelBtPort!.isNotEmpty &&
      panelBtApiKey != null && panelBtApiKey!.isNotEmpty;

  bool get hasAnyPanel => hasPanel1Panel || hasPanelBt;

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'username': username,
        if (password != null) 'password': password,
        if (privateKey != null) 'privateKey': privateKey,
        if (passphrase != null) 'passphrase': passphrase,
        if (panel1PanelPort != null) 'panel1PanelPort': panel1PanelPort,
        if (panel1PanelApiKey != null) 'panel1PanelApiKey': panel1PanelApiKey,
        if (panelBtPort != null) 'panelBtPort': panelBtPort,
        if (panelBtApiKey != null) 'panelBtApiKey': panelBtApiKey,
      };
}
