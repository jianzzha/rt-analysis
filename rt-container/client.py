from __future__ import print_function
import logging
import grpc
import rpc_pb2
import rpc_pb2_grpc
import time


def run():
    with grpc.insecure_channel('localhost:50051') as channel:
        stub = rpc_pb2_grpc.TrafficgenStub(channel)
        response = stub.isTrafficgenRunning(rpc_pb2.IsTrafficgenRunningParams())
        print("Trafficgen is running" if response.isTrafficgenRunning else "Trafficgen is not running")
        response = stub.getResult(rpc_pb2.GetResultParams())
        print("port %s rx_pps: %.2f" %(response.stats[0].port, response.stats[0].rx_pps))
        print("port %s rx_pps: %.2f" %(response.stats[1].port, response.stats[1].rx_pps))
        response = stub.isResultAvailable(rpc_pb2.IsResultAvailableParams())
        print("result %s available" %("is" if response.isResultAvailable else "not"))
        response = stub.startTrafficgen(rpc_pb2.BinarySearchParams(
            search_runtime=10,
            validation_runtime=10,
            num_flows=1,
            device_pairs="0:1",
            frame_size=64,
            max_loss_pct=0.002,
            sniff_runtime=10
        ))
        print("start trafficgen: %s" % ("success" if response.success else "fail"))
        """
        time.sleep(3)
        response = stub.stopTrafficgen(rpc_pb2.StopTrafficgenParams())
        print("stop trafficgen: %s" % ("success" if response.success else "fail"))
        """

if __name__ == '__main__':
    logging.basicConfig()
    run()
