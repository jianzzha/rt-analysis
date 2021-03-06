import sys
import argparse
import re
import matplotlib.pyplot as plt


class Cyclic(object):
    def __init__(self, cmdline_args):
        self.args = cmdline_args
        # number of cores
        self.n_cores = 0
        # summary: {total:[], min_latency:[], ...}
        self.summary = {}
        # latency: {1:[], 2:[]...}
        self.latency = {}

    def processing(self):
        """take input file line by line,
            grep summary latency info from comment line,
            grep latency data from data line,
            set instance data: n_cores, latency"""

        # pattern to match comment line
        comment = re.compile(r'\s*#')
        # pattern to match Total:
        total = re.compile(r'\s*# Total:')
        # pattern to match min latency:
        min_latency = re.compile(r'\s*# Min Latencies:')
        # pattern to match Avg latency:
        avg_latency = re.compile(r'\s*# Avg Latencies:')
        # pattern to match Max latency:
        max_latency = re.compile(r'\s*# Max Latencies:')
        # pattern to match overflows:
        overflow = re.compile(r'\s*# Histogram Overflows:')
        # patten to find the latency count
        count = re.compile(r'\d+')
        line = self.args.input.readline()
        while line:
            comment_match = comment.match(line)
            if comment_match:
                # comment line
                for pattern_str in ["total", "min_latency", "avg_latency", "max_latency", "overflow"]:
                    pattern = locals()[pattern_str]
                    summary_match = pattern.match(line)
                    if summary_match:
                        self.summary[pattern_str] = self._convert_list_str_to_int(count.findall(line))
                        break
            elif count.match(line):
                # not comment line
                tempList = line.split()
                if not self.n_cores:
                    # first is the latency number, rest are each core count
                    self.n_cores = len(tempList) - 1
                self.latency[int(tempList[0])] = self._convert_list_str_to_int(tempList[1:])
            line = self.args.input.readline()

        if self.args.mode == 'calc':
            self.calc()
        elif self.args.mode == 'plot':
            self.plot()
        else:
            pass

    def _convert_list_str_to_int(self, l):
        """internal func to convert string list to int list"""
        result = []
        for i in l:
            result.append(int(i))
        return result

    def plot(self):
        """plot graph, one graph/core"""
        #get per core dict of latency:count
        x = self.latency.keys()
        legend_list = []
        fig = plt.figure()
        for core in range(self.n_cores):
            y = [self.latency[i][core] for i in x]
            plt.plot(x, y)
            legend_list.append("CPU%s" %(core+1))
        plt.yscale('log')
        plt.title("Latency plot")
        plt.xlabel("Latency(us)")
        plt.ylabel("Number of latency samples")
        plt.legend(legend_list)
        plt.show()
        if self.args.saveplot:
            fig.savefig(self.args.output, dpi=fig.dpi)
        plt.close('all')


    def calc(self):
        """count from 0 to what upper bound latency compose
            the self.percentile of the entire data set
        """
        self.percentile_latency = [0 for core in range(self.n_cores)]
        per_core_flag = [0 for core in range(self.n_cores)]
        aggregate_flag = 0
        accu = 0
        total = sum(self.summary['total'])
        target = int(total * self.args.percentile / 100)
        accu_per_core = [0 for core in range(self.n_cores)]
        total_per_core = [self.summary['total'][core] for core in range(self.n_cores)]
        target_per_core = [int(total_per_core[core] * self.args.percentile / 100) for core in range(self.n_cores)]
        for latency, countlist in self.latency.iteritems():
            if not aggregate_flag:
                accu += sum(countlist)
                if accu >= target:
                    aggregate_flag = 1
                    aggregate_latency = latency
            for core in range(self.n_cores):
                if not per_core_flag[core]:
                    accu_per_core[core] += countlist[core]
                    if accu_per_core[core] >= target_per_core[core]:
                        self.percentile_latency[core] = latency
                        per_core_flag[core] = 1
        print "%s%% measured latency:" % self.args.percentile
        if self.args.aggregate:
            print "%s" % aggregate_latency
        else:
            for core in range(self.n_cores):
                print "%s" % self.percentile_latency[core]


def process_cmd_line():
    """ parse cmd line and return args object """
    parser = argparse.ArgumentParser(description='Process cyclictest result')
    # --input defaults to std input
    parser.add_argument('-i', '--input', type=argparse.FileType('r'), default=sys.stdin, help='cyclictest result file')
    parser.add_argument('-s', '--saveplot', action='store_true', help='save plot in file specified by --output')
    parser.add_argument('--aggregate', action='store_true', help='aggregate data from all CPUs')
    parser.add_argument('-o', '--output', default="plot.png", help='plot output file if --saveplot')
    parser.add_argument('--percentile', type=float, default=99.99, help='what latency range makes up this percentile')
    parser.add_argument('mode', default='calc', nargs='?', choices=['calc', 'plot'], help='processing mode')
    args = parser.parse_args()
    return args


if __name__ == "__main__":
    cyclic = Cyclic(process_cmd_line())
    cyclic.processing()
