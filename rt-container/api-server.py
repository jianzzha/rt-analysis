#!/usr/bin/env python
import json
import os
import subprocess
import argparse
from flask import Flask
from flask import jsonify
from flask import request

STATUS_OK = 'OK'
STATUS_ERROR = 'ERROR'
STATUS_SUBMITTED = 'SUBMITTED'
STATUS_NOT_FOUND = 'NOT_FOUND'

class global_vars(object):
     args=None;
     cwd = os.path.dirname(__file__)


def result_json(status, message):
    body = {
        'status': status,
        'result': message
    }
    return body


def load_json(data):
    return json.loads(json.dumps(data))


# make sure this file name is in sync with binary-search.py
lock_file = "/tmp/binary-search-running"

class Trafficgen(object):
    pid = NULL
    @staticmethod
    def start_trex_server(config):
        cmd = ["./binary-search.py", "--traffic-generator=trex-txrx", "--rate-tolerance=10", "--use-src-ip-flows=1",
               "--use-dst-ip-flows=1", "--use-src-mac-flows=1", "--use-dst-mac-flows=1", "--use-src-port-flows=0",
               "--use-dst-port-flows=0", "--use-encap-src-ip-flows=0", "--use-encap-dst-ip-flows=0",
               "--use-encap-src-mac-flows=0", "--use-encap-dst-mac-flows=0", "--use-protocol-flows=0",
               "--rate-unit=%", "--rate=100", "--traffic-direction=bidirectional"]
        for key, value in config.iteritems():
            cmd.append("--{}={}".format(key, value))
        pid = subprocess.Popen(cmd) 


app = Flask(__name__)

busy_msg = 'traffigen is running another job'
idle_msg = 'traffigen is not running'
not_found_msg = 'results not found'
submitted_msg = 'job submitted'

@app.route('/start', methods=['POST'])
def _start():
    config = load_json(request.json)
    if not config:
        config = {}
    if os.path.exists(lock_file):
        return jsonify(result_json(STATUS_ERROR, busy_msg))
    Trafficgen.start_trex_server(config) 
    return jsonify(result_json(STATUS_SUBMITTED, submitted_msg))

@app.route('/status', methods=['GET'])
def _get_status():
    if os.path.exists(lock_file):
        return jsonify(result_json(STATUS_OK, busy_msg))
    else:
        return jsonify(result_json(STATUS_OK, idle_msg))

@app.route('/result', methods=['GET'])
def _get_result():
    result_file = global_vars.args.output_dir + '/stats.json'
    if os.path.exists(result_file):
        with open(result_file) as json_file:
            data = json.load(json_file)
            return jsonify(result_json(STATUS_OK, json.dumps(data)))
    else:
        return jsonify(result_json(STATUS_ERROR, not_found_msg))


def process_options():
    parser = argparse.ArgumentParser(usage="""
    API server to get status and result from the backend trafficgen/testpmd/cyclictest.
    """);
    parser.add_argument('--output-dir',
                        dest='output_dir',
                        help='Directory where the backend worker store its test result',
                        default="./"
                       )
    parser.add_argument('--device-pairs',
                        dest='device_pairs',
                        help='dpdk device pair in the form of 1:2,3:4, this option is only valid for binary-search',
                        default="1:2"
                       )
    global_vars.args = parser.parse_args()


def main():
    process_options()
    app.run(host= '0.0.0.0')
    
if __name__ == "__main__":
    main()

