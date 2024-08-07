import argparse
import json
import threading
import queue
from types import SimpleNamespace
from getpass import getpass
from linux.connectivity import lnx_test_connectivity
from windows.connectivity import win_test_connectivity

# Queue for threading
q = queue.Queue()
lock = threading.Lock()
test_results = []
credentials = {}

def process_test_job(job):
    host_credentials = None
    if job.runs_on != 'localhost':
        host_credentials = credentials[job.runs_on]

    if job.category == "connectivity" and job.platform == "linux":
        result = lnx_test_connectivity(job, host_credentials)
        test_results.append(result)
    elif job.category == "connectivity" and job.platform == "windows":
        result = win_test_connectivity(job, host_credentials)
        test_results.append(result)
    elif job.category == "domain":
        print(f"Running domain test {job.name}")
    elif job.category == "services":
        print(f"Running services check {job.name}")
    elif job.category == "agents":
        print(f"Running agents validation {job.name}")

def worker():
    while True:
        job = q.get()
        if job is None:
            break
        process_test_job(job)
        q.task_done()

def main():
    
    # Get the list of test jobs from a flattened input json
    test_jobs = []
    parser = argparse.ArgumentParser(description="Test Automation Script")
    parser.add_argument('test_plan_file', type=str, help='Path to the test plan JSON file')
    args = parser.parse_args()
    
    
    # Load test plan
    with open(args.test_plan_file, 'r') as f:
        input_json = json.load(f)
    for category, items in input_json.items():
        for item in items:
            flat_item = {"category": category}
            flat_item.update(item)
            test_jobs.append(SimpleNamespace(**flat_item))

    # Get Credentials
    target_runon_servers = []
    for job in test_jobs:
        if not job.runs_on in target_runon_servers:
            target_runon_servers.append(job.runs_on)
            if job.runs_on != 'localhost':
                username = input(f"Username for {job.runs_on}: ")
                password = getpass(f"Password for {job.runs_on}/{username}: ")
                #password = input(f"Password for {job.runs_on}/{username}: ")
                credentials[job.runs_on] = {"username": username, "password": password}

    # Create 10 threads
    threads = []
    for _ in range(10):
        t = threading.Thread(target=worker)
        t.start()
        threads.append(t)

    # Process jobs
    for job in test_jobs:
        q.put(job)

    # Block until all tasks are done
    q.join()

    # Stop workers
    for _ in range(10):
        q.put(None)
    for t in threads:
        t.join()

    # Print output
    for result in test_results:
        print(result)
if __name__ == "__main__":
    main()