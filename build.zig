const builtin = @import("builtin");
const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("zfetch", "src/main.zig");
    exe.use_stage1 = true; // Temporary
    exe.setTarget(target);
    exe.setBuildMode(mode);

    exe.addPackagePath("decor", "lib/zig-decor/decor.zig");

    if (builtin.target.os.tag == .macos) {
        exe.linkFramework("ApplicationServices");
        exe.linkFramework("IOKit");
    }
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run zfetch");
    run_step.dependOn(&run_cmd.step);
}
