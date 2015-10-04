## Introduction

This tutorial describes how to install FALCON and how to use it to assemble an example genome in a Rocks cluster using SGE job queueing system.

## Installation

FALCON can be installed with gcc 4.8.2+ and python 2.7.3+. virtualenv from python installation is required to create a virtual environment. So make sure that your system has these components (python 2.7.3+, pip, virtualenv) installed already. If not, consult google to install them. We will need two python packges pypeFLOW and FALCON and we need compile the DALINGER code and put the binary executables into the virtual environment.

Here are the commands that can install FALCON on a cluster assuming you have all the required dependencies.

```
mkdir falcon
cd falcon
wget --no-check-certificate https://raw.githubusercontent.com/PacificBiosciences/FALCON/master/examples/build_env.sh
source build_env.sh
cd ..
```

Feel free to read the `build_env.sh` file to know what it does. Essentially it calls virtualenv to set up a virtual environment, and then clone a few github repositories and install several components for FALCON.

Now we need to activate the virtual environment:

```
source $PWD/fc_env/bin/activate
```

After successful activation, you can check your python environment (note that the `(fc_env)` was added by the virtual environment so that user easily know that they are inside a virtual env):

```
(fc_env) $ which python
installation_dir/fc_env/bin/python
```

You can add virtual environment activation command to your `~/.bashrc` file such that you don’t have to type the full path to use it:

```
alias falcon_activate="source $HOME/try_falcon_installation/fc_env/bin/activate"
```

## Overview of Hierarchical Genome Assembly Process (HGAP)

A "Hierarchical Genome Assembly Process" is constituted of the following steps for generating a genome assembly from a set of sequencing reads:

- Raw sub-reads overlapping for error correction
- Pre-assembly and error correction
- Overlapping detection of the error corrected reads
- Overlap filtering
- Constructing graph from overlaps
- Constructing contig from graph

FACLCON is written with the assumption of using SGE. The script fc_run.py can drive the workflow managing checking the data dependency and submitting the jobs for each step and generating a draft assembly from the giving data. It takes a configuration file as single input. The input files of the raw sequence data is included in the configuration files.

### run E.coli example analysis

Here are the commands to try assembling an E. Coli genome. Note here I modified the [configuration file](https://github.com/WangGenomicsLab/PacBioTutorial/blob/master/examples/fc_run_ecoli.cfg) to make it run on biocluster. The analysis should finish in 20 minutes. You will get one sequence in the ecoli_test/2-asm/p_ctg.fa file, which is 4.6 Mbp.

```
falcon_activate
mkdir ecoli_test
cd ecoli_test/
find /home/yunfeiguo/projects/data/try_falcon_dont_rm/data -name "*.fasta" > input.fofn
cp /home/yunfeiguo/projects/data/try_falcon_dont_rm/fc_run_ecoli.cfg .
fc_run.py fc_run_ecoli.cfg
```

### run CHM1 example analysis
CHM1 genome is the result of replication of paternal genome, creating a haploid equivalent. The data comes from Mark Chaisson's Nature paper. The assembly process should finish in less than 2 days on biocluster (when enough compute nodes are available) and give configs with N50 of 57.6 Kbp. The configuration file can also be found [here](https://github.com/WangGenomicsLab/PacBioTutorial/blob/master/examples/fc_run_chm1.cfg).

```
falcon_activate
mkdir chm1_test
cd chm1_test/
cp /home/yunfeiguo/projects/PacBio_reference_genome/falcon_aln/try_CHM1_20150311/all.fofn .
cp /home/yunfeiguo/projects/PacBio_reference_genome/falcon_aln/try_CHM1_20150311/fc_run_chm1.cfg .
fc_run.py fc_run_chm1.cfg
```

The recommended paramters for CHM1 is below (obviously one needs to modify SGE/hardware-related parts to suit the specific hardware system):

```
[General] 
# list of files of the initial bas.h5 files 
input_fofn = input.fofn 
#input_fofn = preads.fofn 

input_type = raw 
#input_type = preads 

# The length cutoff used for seed reads used for initial mapping 
length_cutoff = 10000 

# The length cutoff used for seed reads used for pre-assembly 
length_cutoff_pr = 6000 


sge_option_da = -pe smp 4 -q bigmem 
sge_option_la = -pe smp 20 -q bigmem 

sge_option_pda = -pe smp 6 -q bigmem 
sge_option_pla = -pe smp 16 -q bigmem 
sge_option_fc = -pe smp 24 -q bigmem 
sge_option_cns = -pe smp 12 -q bigmem 

pa_concurrent_jobs = 96 
cns_concurrent_jobs = 96 
ovlp_concurrent_jobs = 96 

pa_HPCdaligner_option = -v -dal128 -t16 -e.70 -l1000 -s1000 
ovlp_HPCdaligner_option = -v -dal128 -t32 -h60 -e.96 -l500 -s1000 

pa_DBsplit_option = -x500 -s400 
ovlp_DBsplit_option = -x500 -s400 

falcon_sense_option = --output_multi --min_idt 0.70 --min_cov 4 --max_n_read 200 --n_core 10 

overlap_filtering_setting = --max_diff 40 --max_cov 25 --min_cov 2 --n_core 24 
```

Note that FALCON provides fc_run_LG.py script in addition to fc_run.py script. It was explained in [this page](https://github.com/PacificBiosciences/FALCON/issues/45): "The LG example has been used for large, human-scale assemblies, but the best choice of parameters depend on your cluster's hardware and software settings."

To monitor the progress of the tasks for the daligner job, you can run `find . -name "job_*done" | wc` in the `0-rawreads` directory.

### Details about execution

#### SGE parameter tuning
I used the following options to control FALCON job submission behavior in SGE(Sun Grid Engine) in the assembly of hx1 (230+ flowcells). As of 6/19/2015, biocluster has 30 nodes with 80GB (consumable set to be 84GB), 8 nodes with 48GB (consumable 56GB). All nodes have 12 CPU cores.
```
#for error correction, 26GB is minimum
sge_option_da = -pe smp 4 -l h_vmem=7g
sge_option_la = -pe smp 6
#for pre-assembly, 32GB is minimum
sge_option_pda = -pe smp 4 -l h_vmem=9g
sge_option_pla = -pe smp 6
sge_option_fc = -pe smp 12
sge_option_cns = -pe smp 7

pa_concurrent_jobs = 104
cns_concurrent_jobs = 37
ovlp_concurrent_jobs = 104
```
`sge_option_da` and `seg_option_pda` controls submission for DALIGNER jobs. Based on test runs on CHM1 data, 26GB memory is minimum for DALIGNER with 4 threads. For DALIGNER in preassembly step, 32GB is minimum. 

For the remaining programs, the default 4GB per thread is used and it works well in practice.

When running 120 DALIGNER jobs on biocluster, nas-0-0 becomes very slow, this suggests too much I/O burden on the storage node. Measures should be taken to reduce I/O load otherwise we can't keep adding compute nodes (Jun30, 2015).

#### monitor assembly progress

[show_falcon_progress](https://github.com/WangGenomicsLab/PacBioTutorial/blob/master/scripts/show_falcon_progress) is a simple script based on Jason Chin's advice ([#46](https://github.com/PacificBiosciences/FALCON/issues/46)). It shows falcon progress (particularly, how many daligner jobs are done since daligner is the slowest step).

An example usage is shown below:

````
[11:50 yunfeiguo@biocluster PacBioTutorial]$ show_falcon_progress ~/projects/PacBio_reference_genome/falcon_aln/try_CHM13_20150406/0-rawreads
NOTICE: calculating total number of jobs (for DALIGNER only)
NOTICE: there are 1260 'job_*' folders (assuming one job per folder)
NOTICE: counting jobs done, this may take a while
NOTICE: 201 (15.95 %) jobs done.
````

#### Ways to reduce I/O load

On biocluster, the central storage node, nas-0-0, gets very busy when we have around 60 DALIGNER jobs (each with 4 threads) or 15 LA4Falcon jobs (each with 8 threads) running. However, it is possible to reduce I/O load on nas-0-0 by utilizing local storage (2~3 TB) on compute nodes and network bandwidth between compute nodes.

**The following methods are not yet tested.**
##### 1. Local file staging
Based on this [link](http://www3.imperial.ac.uk/bioinfsupport/help/cluster_usage/datastaging) and [#39](https://github.com/PacificBiosciences/FALCON/issues/39), we can copy input files to the compute node and copy the results back. SGE provides the job with a temporary folder `$TMPDIR` and removes upon completion of the job. The reason I guess is that although total amount of data transferred is the same, the number of I/O requests drops dramatically, essentially elliminating network latency. Also, in some setps, there are lots of random access, which puts huge burden for HDDs \([SSD is better at this job](http://www.tomshardware.com/reviews/ssd-upgrade-hdd-performance,3023-6.html)\).

I have forked a [FALCON repository](https://github.com/WangGenomicsLab/FALCON) and wrote file staging code for all the jobs. See https://github.com/WangGenomicsLab/FALCON/releases/tag/v1.0.0 for code.


### details about option tuning, assembly procedure

#### Raw sub-reads overlapping for error correction

In this version of the Falcon kit, the overlapping is done with a modified version of Gene Myers' Daligner (http://dazzlerblog.wordpress.com). As of `709c02d`, number of threads in [DALIGNER](https://github.com/thegenemyers/DALIGNER) is hard-coded in `filter.h`, and it must be powers of 2.

- input_fofn

    The option input_fofn points to the file that contains all input data. fasta2DB from Daligner is called within fc_run.py. 

- input_type

    This version of fc_run.py supports running assembly from error corrected reads. If you set the option input_type = preads rather than input_type = raw, fc_run.py will assume the fasta files in input_fofn are all error-corrected reads.

- length_cutoff

    You will need to decide the length cutoff. Typically, it will be nice to chose the threshold at the point you can get longest 15x to 20x for genome assembly. However, if the computational resource is abundant and you might find other applications of error corrected reads, you can set lower length cutoff to get more error corrected reads for your applications.

    The option length_cutoff controls the cutoff used during the error correction process and length_cutoff_pr controls the cutoff used for the later assembly overlapping step. In the final assembly, more reads may not lead to a better assembly due to some of the reads can be noisy and create false links in the assembly graph. Sometimes, it might make sense to try different length_cutoff_pr as it is relative cheap for computation than the first overlapping step for error correction. One strategy is to chose smaller length_cutoff and do the computation once. Later, we can use differentlength_cutoff_pr for getting better assembly.

- pa_concurrent_jobs

    The option pa_concurrent_jobs controls the number of concurrent jobs that can be submitted by fc_run.py. sge_option_da and sge_option_la controls the job queue and the number of slots of the daligner jobs. The default number of thread used by daligner is 4. However, depending on the cluster configuration and the amount of memory of the computational nodes, you might want to use more than 4 slots. The best to chose the right number is to consult your local HPC gurus and do some small experiments first.
The total number of jobs that is run is determined how one "splits" the sequence database. You should read Gene Myers's blog ( http://dazzlerblog.wordpress.com ) carefully to know how to tune the option pa_DBsplit_option and pa_HPCdaligner_option. Generally, for large genome, you should use -s400 (400Mb sequence per block) inpa_DBsplit_option. This will make smaller number of jobs but each job runs longer. However, if you have job queue system which has limit of how long a job can run, it might be desirable to have smaller number for the -s option.

- dal

    Another parameter affects the total number of jobs is the -dal option in pa_HPCdaligner_option. The number for the -dal option determines how many blocks are compared to each in single jobs. Larger number gives larger jobs but smaller amount of total jobs. Smaller number gives smaller jobs but you have to submit more jobs to your cluster.

- pa_HPCdaligner_option

    The -s1000 in pa_HPCdaligner_option makes the trace points sparse to save some disk space (not much though). We also ignore all reads less than 1kb by specifying -l1000.

#### Pre-assembly and error correction

The output of daligner is a set of .las files that contains information of the alignments between the reads. Such information is dumped as sequences for error correction by a binary executable LA4Falcon to fc_consensus.py. The fc_consensus.py does the work to generate consensus. (The alignments for generating consensus are done with back-end code written in C for speed.)

- falcon_sense_option

    The fc_consensus.py has many options. You can use the falcon_sense_option to control it. In most of case, the --min_cov and --max_n_read are the most important options. --min_cov controls when a seed read getting trimmed or broken due to low coverage. --max_n_read put a cap on the number of reads used for error correction. In high repetitive genome, you will need to put smaller --max_n_read to make sure the consensus code does not waste time aligning repeats. The longest proper overlaps are used for correction to reduce the probability of collapsed repeats.

- cns_concurrent_jobs

    One can use cns_concurrent_jobs to control the maximum number of concurrent submitted to the job management system.

#### Overlapping detection of the error corrected reads

This part is pretty much the same as the first overlapping stage, although some "hacks" are necessary as daligner only take native raw reads as default.
fc_run.py generates a fasta file of error corrects where the fasta header is parse-able by daligner. The following parameters control the computation process for this step:

```
    sge_option_pda = -pe smp 8 -q jobqueue
    sge_option_pla = -pe smp 2 -q jobqueue
    ovlp_concurrent_jobs = 32
    ovlp_DBsplit_option = -x500 -s50
    ovlp_HPCdaligner_option = -v -dal4 -t32 -h60 -e.96 -l500 -s1000
```

The setting is mostly parallel to the first overlapping step. The major difference is the -e option in ovlp_HPCdaligner_option. The error rate is much lower now so we expect much higher correlation between the p-reads.

#### Overlap filtering

- max_diff

    The --max_diff parameter can be used to filter out the reads where one ends has much more coverage than the other end.

-max_cov min_cov max_diff

    If the overall coverage of the error corrected reads longer than the length cut off is known and reasonable high (e.g. greater than 20x), it might be safe to set min_cov to be 5, max_cov to be three times of the average coverage and the max_diff to be twice of the average coverage. However, in low coverage case, it might better to set min_cov to be one or two. A helper script called fc_ovlp_stats.py can help to dump the number of the 3' and 5' overlap of a given length cutoff, you can plot the distribution of the number of overlaps to make a better decision.


#### Constructing graph from overlaps

Given the overlapping data, the string graph is constructed by fc_ovlp_to_graph.py using the default parameters.fc_ovlp_to_graph.py generated several files representing the final string graph of the assembly. The final ctg_path contain the information of the graph of each contig. A contig is a linear of path of simple paths and compound paths. "Compound paths" are those subgraph that is not simple but have unique inlet and outlet after graph edge reduction. They can be induced by genome polymorphism or sequence errors. By explicitly encoding such information in the graph output, we can examine the sequences again to classify them later.


#### Constructing contig from graph

The final step to create draft contigs is to find a single path of each contig graph and to generate sequences accordingly. The script "fc_graph_to_contig.py" takes the sequence data and graph output to construct contigs. It generated all associated contigs at this moment.

#### Examine overlap count

To tune the overlap filtering parameters (`overlap_filtering_setting` line in configuration), one may want to examine the overlap distribution. The [gen_ovlp_stats](https://github.com/WangGenomicsLab/PacBioTutorial/blob/master/scripts/gen_ovlp_stats) and [plot_ovlp_hist.R](https://github.com/WangGenomicsLab/PacBioTutorial/blob/master/scripts/plot_ovlp_hist.R) contain commands that can generate overlap count statistics and a PDF file containing histograms and scatterplots of 3' and 5' end overlap counts. Some example PDFs can be found in [example](https://github.com/WangGenomicsLab/PacBioTutorial/blob/master/examples).

## Troubleshootting

### python build_rdb error

Sometimes the following error occur:

```
Your job 18921 ("build_rdb-e0b78891") has been submitted
Exception in thread Thread-6:
Traceback (most recent call last):
  File "/home/kaiwang/usr/python/lib/python2.7/threading.py", line 810, in __bootstrap_inner
    self.run()
  File "/home/kaiwang/usr/python/lib/python2.7/threading.py", line 763, in run
    self.__target(*self.__args, **self.__kwargs)
  File "/home/kaiwang/usr/falcon/fc_env/lib/python2.7/site-packages/pypeflow-0.1.1-py2.7.egg/pypeflow/task.py", line 317, in __call__
    runFlag = self._getRunFlag()
  File "/home/kaiwang/usr/falcon/fc_env/lib/python2.7/site-packages/pypeflow-0.1.1-py2.7.egg/pypeflow/task.py", line 147, in _getRunFlag
    runFlag = any( [ f(self.inputDataObjs, self.outputDataObjs, self.parameters) for f in self._compareFunctions] )
  File "/home/kaiwang/usr/falcon/fc_env/lib/python2.7/site-packages/pypeflow-0.1.1-py2.7.egg/pypeflow/task.py", line 812, in timeStampCompare
    if min(outputDataObjsTS) < max(inputDataObjsTS):
ValueError: max() arg is an empty sequence

 No target specified, assuming "assembly" as target 
Traceback (most recent call last):
  File "/home/kaiwang/usr/falcon/fc_env/bin/fc_run.py", line 4, in <module>
    __import__('pkg_resources').run_script('falcon-kit==0.2.1', 'fc_run.py')
  File "/home/kaiwang/usr/falcon/fc_env/lib/python2.7/site-packages/pkg_resources/__init__.py", line 723, in run_script
    self.require(requires)[0].run_script(script_name, ns)
  File "/home/kaiwang/usr/falcon/fc_env/lib/python2.7/site-packages/pkg_resources/__init__.py", line 1636, in run_script
    exec(code, namespace, namespace)
  File "/home/kaiwang/usr/falcon/fc_env/lib/python2.7/site-packages/falcon_kit-0.2.1-py2.7-linux-x86_64.egg/EGG-INFO/scripts/fc_run.py", line 641, in <module>
    wf.refreshTargets(updateFreq = wait_time) # larger number better for more jobs
  File "/home/kaiwang/usr/falcon/fc_env/lib/python2.7/site-packages/pypeflow-0.1.1-py2.7.egg/pypeflow/controller.py", line 519, in refreshTargets
    rtn = self._refreshTargets(objs = objs, callback = callback, updateFreq = updateFreq, exitOnFailure = exitOnFailure)
  File "/home/kaiwang/usr/falcon/fc_env/lib/python2.7/site-packages/pypeflow-0.1.1-py2.7.egg/pypeflow/controller.py", line 617, in _refreshTargets
    assert self.jobStatusMap[str(URL)] in ("done", "continue", "fail") 
AssertionError
[1]+  Exit 1                  nohup fc_run.py fc_run.cfg
```

This is usually because FALCON cannot find the FASTA file in the compute node (even though it finds the file from head node of a cluster). Try to change file path to solve this problem.

### Run FALCON with filtered subreads

SMRTAnalysis can generate filtered subreads in FASTA and FASTAQ format. However, falcon does not work with it directly. We have to do two things for the FASTA file: 

1. split reads by smrt cell ID
2. do wrapping on FASTA (width=71 including newline works fine).

Try [split_subread_fa](https://github.com/WangGenomicsLab/PacBioTutorial/blob/master/scripts/split_subread_fa).

### DALIGNER exits without error

Sometimes DALIGNER will exit without an error, but does not generate any output. This occurs because memory is insufficient. For example, if two DALIGNER instances run on a 48GB machine, each may need 30GB. This results in a lot of pagefaults and causes DALIGNER to finish without writing output. Solution is make sure DALIGNER has at least 30GB of memory for its own.

### Re-run `2-asm-falcon` (overlap filtering and contig construction)

Re-run overlap filtering and contig construction step is computationally cheap. When we want to experiment with different parameters for `overlap_filtering_setting`. We can follow the steps shown below:

````
cd your_analysis_dir
mkdir 2-asm-falcon-2
cd 2-asm-falcon-2
cp ../2-asm-falcon/*.sh .
#comment out DB2falcon
#change 2-asm-falcon to 2-asm-falcon-2
#change max_cov, max_diff and other params
vi run_falcon_asm.sh  
source run_falcon_asm.sh #or use qsub
````

###why loss rate is 50% based on output from `DBstats 0-rawreads/raw_reads.db`?
`raw_reads.db` is built to include all raw reads after some initial filters are applied. According to discussion [here](https://github.com/PacificBiosciences/FALCON/issues/62), the initial filters include 500 bp minimum length, NO secondary reads. After looking at the script, I think these initial filters are not applied until database is split. I compared stats with and without `-a` (secondary reads) and found DBstats results are the same, the statistics may not be able to reflect this change.
```
$ cat 0-rawreads/prepare_db.sh
source /home/yunfeiguo/Downloads/falcon_install/wanglab_falcon_installation/fc_env/bin/activate
cd /home/yunfeiguo/projects/PacBio_reference_genome/falcon_aln/hx1_20150513/0-rawreads
hostname >> db_build.log
date >> db_build.log
for f in `cat /home/yunfeiguo/projects/PacBio_reference_genome/falcon_aln/hx1_20150513/wuhan00to10_yale01to02.fofn`; do fasta2DB raw_reads $f; done >> db_build.log
DBsplit -x500 -s400 raw_reads
LB=$(cat raw_reads.db | awk '$1 == "blocks" {print $3}')
HPCdaligner -v -dal128 -t16 -e.70 -l1000 -s1000 -H6000 raw_reads 1-$LB > run_jobs.sh
touch /home/yunfeiguo/projects/PacBio_reference_genome/falcon_aln/hx1_20150525/0-rawreads/rdb_build_done

```
### fix failed ct jobs
ct jobs are dependent on m jobs, m jobs are dependent on d jobs
ct jobs and m jobs have 1-to-1 mapping, that is ct_00755 is dependent on m_00755 for sure. One m job is dependent on many d jobs. Say one `las` file (`raw_reads.739.raw_reads.375.C0.S.las`) is missing, you need to search through all d job scripts to locate the job that uses `raw_reads.739` and `raw_reads.375` as input, and re-run that job.

`get_failed_job_sentinel.pl` in `scripts` folder can help you retrieve all `_done` files that need to be deleted before restarting falcon. It takes a list of IDs for failed ct jobs. Note, however, simply deleting the `_done` files will make falcon re-run all m and ct jobs. It is necessary to use `touch` to modify access time on the `_done` files such that `_done` files for ct jobs are accessed later than those for m jobs. Even with this change, falcon will still rerun all ct jobs (and almost immediately recognize them as *finished*), so one has to `qdel ct_*` jobs manually. After this step, only failed m jobs will remain.

```
perl -e 'opendir DIR,"0-rawreads";while(readdir DIR){if(/(m_\d+)/){system("touch 0-rawreads/$_/$1_done")}}'
perl -e 'opendir DIR,"0-rawreads/preads";while(readdir DIR){if(/(c_\d+)/){system("}}'
```

####details about `las` file naming in Falcon
+ d jobs generate the following `las` files. Each d job is associated with a number (N), here N is `351`. All `las` files generated by this d job will contain N. 
```
raw_reads.184.raw_reads.351.C0.las
raw_reads.351.raw_reads.180.C1.las
...
```
N can also be figured out from `*.sh` file inside each d job folder. The first `raw_reads.xxx` in the `daligner` command indicates N is `802`.
```
/usr/bin/time daligner -v -t16 -H6000 -e0.7 -s1000 raw_reads.802 raw_reads.230 raw_reads.231
```
+ m jobs will sort and merge the `las` files generated by d jobs and at last produce a single `las` file.
```
raw_reads.749.raw_reads.1.C0.las
raw_reads.749.raw_reads.1.N0.las
raw_reads.749.raw_reads.1.C1.las  ==> raw_reads.L1.749.1.las  ==> raw_reads.L2.749.1  ==> raw_reads.L3.749.1 ==> raw_reads.749
...                                   raw_reads.L1.749.2.las      ...                     ...
...                                   ...
```

+ ct jobs will take a single `las` file and generate a `FASTA` file.

## explanations about files and directories
### 0-rawreads
for error correction.
#### 0-rawreads/preads
##### 0-rawreads/preads/out.XXXXX.fa
contains error corrected reads

### 1-preads_ovl
for pre-assembly.
#### 1-preads_ovl/input_preads.fofn
list of file names of error corrected reads in `0-rawreads/preads`
#### 1-preads_ovl/preads_norm.fasta
contains error corrected reads after filtering by `length_cutoff_pr`
### 2-asm-falcon
for scaffold generation.
