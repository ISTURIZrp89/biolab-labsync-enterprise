import 'dart:io';

class HardwareProfile {
  final int ramMB;
  final int vramMB;
  final int cpuCores;
  final String cpuArch;
  final String gpuName;
  final double systemLoad;
  final double temperature;
  final bool isAppleSilicon;
  final bool hasGPU;
  final bool hasMetal;
  final bool hasCUDA;

  HardwareProfile({
    this.ramMB = 0,
    this.vramMB = 0,
    this.cpuCores = 0,
    this.cpuArch = 'unknown',
    this.gpuName = '',
    this.systemLoad = 0,
    this.temperature = 0,
    this.isAppleSilicon = false,
    this.hasGPU = false,
    this.hasMetal = false,
    this.hasCUDA = false,
  });

  int get score {
    int s = 0;
    s += (ramMB ~/ 1024) * 100;
    s += (vramMB ~/ 1024) * 200;
    s += cpuCores * 50;
    if (hasMetal || hasCUDA) s += 500;
    if (isAppleSilicon) s += 300;
    return s;
  }

  String get tier {
    if (score > 5000) return 'premium';
    if (score > 2000) return 'high';
    if (score > 800) return 'medium';
    return 'low';
  }

  Map<String, dynamic> toJson() => {
    'ramMB': ramMB, 'vramMB': vramMB, 'cpuCores': cpuCores,
    'cpuArch': cpuArch, 'gpuName': gpuName, 'systemLoad': systemLoad,
    'isAppleSilicon': isAppleSilicon, 'hasGPU': hasGPU,
    'hasMetal': hasMetal, 'hasCUDA': hasCUDA, 'tier': tier, 'score': score,
  };
}

class HardwareDetector {
  static Future<HardwareProfile> detect() async {
    int ramMB = 0;
    int cpuCores = 0;
    String cpuArch = '';
    bool isAppleSilicon = false;
    bool hasMetal = false;

    try {
      if (Platform.isMacOS) {
        final result = await Process.run('sysctl', ['-n', 'hw.memsize']);
        ramMB = (int.tryParse(result.stdout.toString().trim()) ?? 0) ~/ (1024 * 1024);
        final cores = await Process.run('sysctl', ['-n', 'hw.ncpu']);
        cpuCores = int.tryParse(cores.stdout.toString().trim()) ?? 0;
        final arch = await Process.run('uname', ['-m']);
        cpuArch = arch.stdout.toString().trim();
        isAppleSilicon = cpuArch.contains('arm64');
        final metal = await Process.run('system_profiler', ['SPDisplaysDataType']);
        hasMetal = metal.stdout.toString().contains('Metal');
      } else if (Platform.isLinux) {
        final mem = await Process.run('grep', ['MemTotal', '/proc/meminfo']);
        final match = RegExp(r'(\d+)').firstMatch(mem.stdout.toString());
        if (match != null) ramMB = int.parse(match.group(1)!) ~/ 1024;
        final cores = await Process.run('nproc', []);
        cpuCores = int.tryParse(cores.stdout.toString().trim()) ?? 0;
        final arch = await Process.run('uname', ['-m']);
        cpuArch = arch.stdout.toString().trim();
      } else if (Platform.isWindows) {
        final script = 'Get-CimInstance Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory';
        final result = await Process.run('powershell', ['-Command', script]);
        ramMB = (int.tryParse(result.stdout.toString().trim()) ?? 0) ~/ (1024 * 1024);
        final cores = await Process.run('powershell', ['-Command', '(Get-CimInstance Win32_Processor).NumberOfCores | Measure-Object -Sum | Select-Object -ExpandProperty Sum']);
        cpuCores = int.tryParse(cores.stdout.toString().trim()) ?? 0;
        final arch = await Process.run('powershell', ['-Command', '(Get-CimInstance Win32_Processor).AddressWidth | Select-Object -First 1']);
        cpuArch = 'x64';
      }
    } catch (_) {}

    if (ramMB <= 0) ramMB = 4096;
    if (cpuCores <= 0) cpuCores = 4;

    return HardwareProfile(
      ramMB: ramMB,
      vramMB: isAppleSilicon ? ramMB ~/ 2 : 0,
      cpuCores: cpuCores,
      cpuArch: cpuArch,
      gpuName: isAppleSilicon ? 'Apple Silicon' : 'Unknown',
      systemLoad: 0,
      isAppleSilicon: isAppleSilicon,
      hasGPU: isAppleSilicon || Platform.isLinux || Platform.isWindows,
      hasMetal: hasMetal,
      hasCUDA: false,
    );
  }

  static String recommendedBackend(HardwareProfile hw) {
    if (hw.isAppleSilicon) return 'mlx';
    if (hw.vramMB >= 4096) return 'cuda';
    if (hw.ramMB >= 8192) return 'llama.cpp';
    return 'cpu';
  }

  static String recommendedModel(HardwareProfile hw) {
    if (hw.tier == 'premium') return 'llama-3.1-8b';
    if (hw.tier == 'high') return 'phi-3-mini';
    if (hw.tier == 'medium') return 'tinyllama';
    return 'gemma-2b';
  }
}
