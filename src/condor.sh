#!/bin/bash

echo $HOME
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HOME/.mujoco/mujoco200/bin
cd /mnt/nfs/gcp-condor/src
$HOME/miniconda/envs/example-env/bin/python main.py --pid=$1
