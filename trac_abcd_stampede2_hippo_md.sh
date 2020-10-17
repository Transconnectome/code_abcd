#!/bin/bash

list=$1
N=`wc ${1} | awk '{print $1}'`
threads=12
#threadsX2=$((${threads}*2))

ABCD=/scratch/03263/jcha9928/data/ABCD/
ABCD_code=$ABCD/code_abcd
ABCD_job=$ABCD_code/job
#DATA_target=$STERN/image03/dwi_eddy

CMD_batch=$ABCD_code/cmd1.ABCD.batch.tckgen.${list}
rm -rf $CMD_batch


i=1
for s in `cat $ABCD_code/$list`
do
#s=`echo $SUBJECT | egrep -o '[0-9]{8}'`

  CMD=$ABCD_job/tckgen.cmd.stampede2.${s}
  rm -rf $CMD

  LOG=$ABCD_job/tckgen.log.stampede2.${s}
  rm -rf $LOG

  #subject=`echo $s | cut -d "_" -f1`
  #sess=`echo $s | cut -d "_" -f2`
subject=${s}
#CMD_sub=$ABCD/code_hbn_stampede/job/cmd2_sub.trac.${s}
#rm -rf $CMD_sub


#echo ${SUBJECT}

cat<<EOC >$CMD
#!/bin/bash
source ~/.bashrc
#DATA_source=$ABCD/data/${s}
#DATA_target=$ABCD/data/${s}

################################################################################
####      SET UP OPEN MP THREADS ###############################################
ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=$threads
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS
################################################################################

###############################################################################
################# CHANGE WORKING FOLDER TO SCRATCH ############################
###############################################################################

cd $ABCD/data_bids_derivatives/mrtrix/sub-${s}

################################################################################
################################################################################

mrconvert /scratch/03263/jcha9928/data/ABCD/data_bids_derivatives/freesurfer/sub-${s}/ses-baselineYear1Arm1/mri/lh.hippoAmygLabels-T1-T2.v21.FSvoxelSpace.mgz \
     lh.hippoAmygLabels-T1-T2.v21.FSvoxelSpace.nii.gz -force

mrconvert /scratch/03263/jcha9928/data/ABCD/data_bids_derivatives/freesurfer/sub-${s}/ses-baselineYear1Arm1/mri/rh.hippoAmygLabels-T1-T2.v21.FSvoxelSpace.mgz \
     rh.hippoAmygLabels-T1-T2.v21.FSvoxelSpace.nii.gz -force

mrconvert mr_DTI_MD.mif.gz \
     mr_DTI_MD.nii.gz
mrconvert mr_DTI_RD.mif.gz \
     mr_DTI_RD.nii.gz
mrconvert mr_DTI_AD.mif.gz \
     mr_DTI_AD.nii.gz
mrconvert mr_DTI_FA.mif.gz \
     mr_DTI_FA.nii.gz

time $WORK/code/antswarp mr_meanb0_bet \
                         brain

for metric in MD FA AD RD
do
  WarpImageMultiTransform 3 \
   mr_DTI_\${metric}.nii.gz \
   mr_DTI_\${metric}_brain_warped.nii.gz \
   -R brain.nii.gz \
   --use-BSpline \
mr_meanb0_bet2brain_synantsWarp.nii.gz mr_meanb0_bet2brain_synantsAffine.txt
done


##calulcating regional diffusion coefficients

roilist="7001 7003 7005 7006 7007 7008 7009 7010 7015 203 211 212 215 226 233 \
234 235 236 237 238 239 240 241 242 243 244 245 246"

rm stats_hippo_dti.csv

for metric in MD FA AD RD
  do
    for r in \`echo \$roilist\`
      do
        for hemi in lh rh
          do
            fslmaths \${hemi}.hippoAmygLabels-T1-T2.v21.FSvoxelSpace -thr \$r -uthr \$r -bin /tmp/${s}_\${hemi}_\${r}

            export mean=\`fslmeants -i mr_DTI_\${metric}_brain_warped.nii.gz -m /tmp/${s}_\${hemi}_\${r}\`

            [ ! -z "\$mean" ] && echo "\${hemi}_\${metric}_\${r}, \$mean" >> stats_hippo_dti.csv
          done
      done
  done

echo "I THINK EVERYTHING IS DONE BY NOW"

EOC

################################################## END OF CMD##########################################################
chmod +x $CMD
echo "$CMD > ./job/output_${s}_\${LAUNCHER_JID}_\${LAUNCHER_TSK_ID} 2>&1" >> $CMD_batch
#echo "$CMD > $ABCD/fs/\`head -n 1 /tmp/tmp_${s}_t1name\`/dwi/output_${s}_\${LAUNCHER_JID}_\${LAUNCHER_TSK_ID} 2>&1" >> $CMD_batch
#echo "$CMD > $ABCD/mrtrix/sub-${s}/output_${s}_\${LAUNCHER_JID}_\${LAUNCHER_TSK_ID} 2>&1" >> $CMD_batch
done


### batch submission############################################################
# rm batch_abcd_*
#
# split -l 256 $CMD_batch batch_abcd_

rm batch_abcd_*
n_list=`wc ${list} | awk '{print $1}'`
# n_split=$((n_list/256+1))
n_split=$((128*48))
# n_split=1971
split -l $n_split $CMD_batch batch_abcd_

for b in `ls batch_abcd_*`
do
launch_script=${ABCD_job}/script_${b}

n_line=`wc -l $b | awk '{print $1}'`
# echo n_line is ${n_line}
# number_of_nodes=`echo $((n_line / 16)) | bc`
# echo number_of_nodes are ${number_of_nodes}


cat<<EOM > $launch_script
#!/bin/bash
#SBATCH -J mrtrx_${b}          # Job name
#%###SBATCH -o ./job/mrtrx_a2.o%j       # Name of stdout output file
#%###SBATCH -e ./job/mrtrx_a2.e%j       # Name of stderr error file
#SBATCH -p skx-normal          # Queue (partition) name
######SBATCH -N `wc -l $b | awk '{print $1}'`               # Total # of nodes
#SBATCH -N 128                            # Total # of nodes
#SBATCH --ntasks-per-node 48            # Total # of mpi tasks
#SBATCH -t 2:00:00        # Run time (hh:mm:ss)
#SBATCH --mail-user=cha.jiook@gmail.com
#SBATCH --mail-type=all    # Send email at begin and end of job
#SBATCH -A TG-IBN180001

# Other commands must follow all #SBATCH directives...
module list
pwd
date
module load launcher
sleep 3

export LAUNCHER_PLUGIN_DIR=\$LAUNCHER_DIR/plugins
export LAUNCHER_RMI=SLURM
export LAUNCHER_JOB_FILE=`echo $b`

# Launch MPI code...
\$LAUNCHER_DIR/paramrun
EOM

echo sbatch $launch_script
done
