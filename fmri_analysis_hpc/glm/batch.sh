#!/bin/bash

#SBATCH --job-name=glm_full_basic
#SBATCH --mail-user=grum90@zedat.fu-berlin.de
#SBATCH --mail-type=end
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=4096
#SBATCH --time=0-10:00:00
#SBATCH --qos=standard

# add Matlab module
module add MATLAB

# specify task session number (1 or 2)
session=1

# specify preprocessing steps: 
# 1=spec conditions; 2=glm; 3=contrasts
analysis_steps="[1,2,3]"
# initial prefix for the data 
prefix="s8wr"

# batch input as subject number for parallelization
subject=${SLURM_ARRAY_TASK_ID}

# run function
matlab -r "glm_hpc(${subject}, ${session}, ${analysis_steps}, '${prefix}')" $MCR_HOME 

