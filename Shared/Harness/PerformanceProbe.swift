import AppKit
import Darwin

/// `--measure <seconds>`: lets the saver run in its window, then measures this process's CPU and
/// memory use and prints them for Tools/perf-check.sh before quitting. It waits `--warmup` seconds
/// (default 10) first, so one-off setup work isn't counted.
enum PerformanceProbe {
    static func start(measuring duration: Double, afterWarmup warmup: Double) {
        // Keep macOS from throttling the app while it's being measured.
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled], reason: "Measuring performance")

        DispatchQueue.main.asyncAfter(deadline: .now() + warmup) {
            let start = (cpu: cpuTime(), wall: ProcessInfo.processInfo.systemUptime)
            var previous = start
            var peakCPU = 0.0
            var peakMemory = memoryFootprint()
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                let now = (cpu: cpuTime(), wall: ProcessInfo.processInfo.systemUptime)
                peakCPU = max(peakCPU, (now.cpu - previous.cpu) / (now.wall - previous.wall) * 100)
                peakMemory = max(peakMemory, memoryFootprint())
                previous = now
                guard now.wall - start.wall >= duration else { return }

                timer.invalidate()
                let average = (now.cpu - start.cpu) / (now.wall - start.wall) * 100
                print(String(format: "MEASURED cpu_average=%.1f cpu_peak=%.1f memory_mb=%.0f", average, peakCPU, Double(peakMemory) / 1_048_576))
                fflush(stdout)
                ProcessInfo.processInfo.endActivity(activity)
                NSApp.terminate(nil)
            }
        }
    }

    /// User plus system CPU time of all of this process's threads, in seconds.
    private static func cpuTime() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return seconds(usage.ru_utime) + seconds(usage.ru_stime)
    }

    private static func seconds(_ time: timeval) -> Double {
        Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000
    }

    /// The memory figure Activity Monitor shows, in bytes.
    private static func memoryFootprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }
}
