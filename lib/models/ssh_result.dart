/// Result of an SSH command execution.
class SshResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const SshResult({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  bool get isSuccess => exitCode == 0;
}
