const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const exe = b.addExecutable("zfetch", "src/main.zig");
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run zfetch");
    run_step.dependOn(&run_cmd.step);
}
