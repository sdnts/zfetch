const builtin = @import("builtin");
const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("zfetch", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkLibC();

    if (builtin.target.os.tag == .macos) {
        exe.linkFramework("ApplicationServices");
    }
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run zfetch");
    run_step.dependOn(&run_cmd.step);
}
