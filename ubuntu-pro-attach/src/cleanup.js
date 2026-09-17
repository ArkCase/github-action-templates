const core = require("@actions/core");
const exec = require("@actions/exec");

async function run()
{
	try
	{
		const ubuntuProEnabled = core.getState("ubuntuProEnabled");
		if (ubuntuProEnabled !== "true") {
			core.info("Ubuntu Pro was not joined, skipping cleanup");
			return;
		}

		core.info("Detaching from Ubuntu Pro");
		await exec.exec("sudo", ["pro", "detach", "--assume-yes"]);
		core.info("Ubuntu Pro has been detached");
	}
	catch (error)
	{
		core.warning(`Ubuntu Pro cleanup failed: ${error.message}`);
	}
}

run();
