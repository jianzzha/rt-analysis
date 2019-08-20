FROM centos
ARG CORES=1
ARG CORE_LIST=2
ARG DURATION=1m
ENV CORES="${CORES}"
ENV CORE_LIST="${CORE_LIST}"
ENV DURATION="${DURATION}"
ENV RESULT_DIR=/cyclictest_results
USER root
COPY CentOS-rt.repo /etc/yum.repos.d/
RUN yum -y --enablerepo=extras install epel-release && \
    yum install -y stress-ng rt-tests git wget && \
    yum clean all && \
    rm -rf /var/cache/yum
ENTRYPOINT ["/bin/bash"]
CMD ["-c", "taskset -c ${CORE_LIST} stress-ng --cpu ${CORES} --cpu-load 100 --cpu-method loop --timeout 24h & cyclictest -q -D ${DURATION} -p 99 -t ${CORES} -h 30 -m -n -a ${CORE_LIST} > ${RESULT_DIR}/cyclictest_${DURATION}.out"]
