# Install pywinrm
#  
import winrm

def win_test_connectivity(job, host_credentials):
    for host in job.destinations:
        for port in job.ports:
            try:
                session = winrm.Session(f'http://{job.runs_on}:5985/wsman', auth=(host_credentials['username'], host_credentials['password']))
                PS_TEST_CONNECTIVITY = f"""
            try {{
                $result = Test-NetConnection -ComputerName {host} -Port {port} -WarningAction SilentlyContinue -ErrorAction SilentlyContinue

                if ($result.TcpTestSucceeded) {{
                    return "Success"
                }} else {{
                    return "Failed"
                }}
            }} catch {{
                return "Error"
            }}
        """
                response = session.run_ps(PS_TEST_CONNECTIVITY)
                if 'Success' in response.std_out.decode():
                    return f"connectivity,{job.runs_on},{host},{port},PASS,"
                else:
                    return f"connectivity,{job.runs_on},{host},{port},FAIL,{response.std_err.decode()}"
            except Exception as e:
                return f"connectivity,{job.runs_on},{host},{port},FAIL,{e}"
