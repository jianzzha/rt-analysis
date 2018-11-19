# rt-analysis
This repo contains script and sample RT test result file
## Usuage examples
### Calculte percentile per CPU
python  cycparse.py --input=cyclictest_stress_1h.out --percentile=99.999

### Plot per CPU
python  cycparse.py --input=rhel75_8cpu_preemtion_stress_nocve_nol1d_24h.out plot

It will generate a figure like this:

![alt text](https://raw.githubusercontent.com/jianzzha/rt-analysis/master/plot.png)

