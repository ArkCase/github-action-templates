const core = require("@actions/core");
const exec = require("@actions/exec");

async function run()
{
	var ubuntuProEnabled = "false";
	try
	{
		const token = core.getInput("ubuntu-pro-token");
		if (!token)
		{
			core.setFailed("No token given - cannot continue");
			return;
		}

		// Mask in the logs
		core.setSecret(token);

		core.info("Installing the Ubuntu Pro client ...");
		await exec.exec("sudo", ["apt-get", "update"]);
		await exec.exec("sudo", ["apt-get", "install", "-y", "ubuntu-pro-client"]);

		const result = await exec.exec("sudo", ["pro", "attach", "--no-auto-enable", token], {
			ignoreReturnCode: true
		});

		switch (result)
		{
			case 0:
				core.info("Ubuntu Pro was attached!");
				break;

			case 2:
				core.info("Ubuntu Pro was already attached!");
				break;

			default:
				core.setFailed(`Failed to attach to Ubuntu Pro with exit code ${result}`);
				return;
		}

		// Success!
		ubuntuProEnabled = "true";
		core.setOutput("attached", ubuntuProEnabled);
	}
	catch (error)
	{
		core.setFailed(error.message);
	}
	finally
	{
		// To be read in the cleanup
		core.saveState("ubuntuProEnabled", ubuntuProEnabled);
		core.exportVariable("UBUNTU_PRO_ACTIVE", ubuntuProEnabled);
	}
}

run();
