def rpi_secure_version(d):
    import subprocess
    project_path = d.getVar('RPI_SECURE_VERSION_PATH', True) or d.getVar('RPI_SECURE_BASE', True)
    cmd = "git describe --tags --always --dirty"
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True, cwd=project_path)
    out, err =  proc.communicate()
    return out.decode("utf-8").rstrip()

RPI_SECURE_VERSION := "${@rpi_secure_version(d)}"
