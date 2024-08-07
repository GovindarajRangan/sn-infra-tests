import socket
import paramiko

TIMEOUT = 5

def lnx_test_connectivity(job, host_credentials):
    if job.runs_on == 'localhost':
        print(f"Running connectivity test {job.name} on locahost")
        for host in job.destinations:
            for port in job.ports:
                try:
                    with socket.create_connection((host, port), TIMEOUT) as sock:
                        print(f"Successfully connected to {host} on port {port}")
                        return f"connectivity,localhost,{host},{port},PASS,"
                except (socket.timeout, socket.error) as e:
                    print(f"Failed to connect to {host} on port {port}: {e}")
                    return f"connectivity,localhost,{host},{port},FAIL,{e}"
    else:
        print(f"Running connectivity test {job.name} on {job.runs_on} using creds {host_credentials}")
        for host in job.destinations:
            for port in job.ports:
                try:
                    print(f"{host}:{port}")
                    ssh = paramiko.SSHClient()
                    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
                    ssh.connect(job.runs_on, port=port, username=host_credentials['username'], password=host_credentials['password'])
                    print(f"Connected to {host}")
                    command = f"nc -zv {host} {port}"  # Using netcat to test port connectivity
                    print(f"Executing command: {command}")
                    stdin, stdout, stderr = ssh.exec_command(command, timeout=TIMEOUT)

                    output = stdout.read().decode()
                    error = stderr.read().decode()

                    ssh.close()

                    print(f"Command executed. Output: {output}, Error: {error}")

                    if 'succeeded' in output or 'succeeded' in error:
                        return f"connectivity,{job.runs_on},{host},{port},PASS,"
                    elif error:
                        return f"connectivity,{job.runs_on},{host},{port},FAIL,{error}"
                    else:
                        return f"connectivity,{job.runs_on},{host},{port},FAIL,Unknown Error"

                except Exception as e:
                    print(f"Exception running connectivity test {job.name}: {e}")
