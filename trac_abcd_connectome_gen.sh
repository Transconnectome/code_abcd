#!/bin/bash

list=$1
N=`wc ${1} | awk '{print $1}'`
threads=12
#threadsX2=$((${threads}*2))

ABCD=/scratch/03263/jcha9928/data/ABCD/
ABCD_code=$ABCD/code_abcd
ABCD_job=$ABCD_code/job
#DATA_target=$STERN/image03/dwi_eddy

CMD_batch=$ABCD_code/cmd1.ABCD.batch.connectome.${list}
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


echo ${s}

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

labelconvert aparc+aseg_diff_flt_dof6_warped_synant_upsample125.nii.gz $FREESURFER_HOME/FreeSurferColorLUT.txt \
	/work/03263/jcha9928/stampede2/app/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt \
	nodes_aparc+aseg_v2.mif.gz -force
sleep 0.1
labelconvert aparc.a2009s+aseg_diff_flt_dof6_warped_synant_upsample125.nii.gz \
             /work/03263/jcha9928/stampede2/app/freesurfer_dev/freesurfer/FreeSurferColorLUT.txt \
	/work/03263/jcha9928/stampede2/app/mrtrix3/share/mrtrix3/labelconvert/fs_a2009s.txt \
	nodes_aparc.a2009s+aseg_v2.mif.gz -force
sleep 0.1


################################################################################
################################################################################
################################### tck2connectome #############################
################################################################################
################################################################################
     ## FA, MD, AD, RD (L2+L3/2)
     
     for im in aparc+aseg_v2 aparc.a2009s+aseg_v2
     do
     #1.count
     tck2connectome -force -zero_diagonal -nthreads ${threads} \
                 mr_track_1M_SIFT.tck nodes_\${im}.mif.gz mr_connectome_sift_1M_\${im}_count_v2.csv
     #tck2connectome -force -zero_diagonal -nthreads ${threads} \
     #            mr_track_global_1e9.tck nodes_\${im}.mif.gz mr_connectome_global1e9_\${im}_count.csv
     #2.length
     tck2connectome -force -zero_diagonal -scale_length -stat_edge mean mr_track_1M_SIFT.tck nodes_\${im}.mif.gz \
                 mr_connectome_sift_1M_\${im}_length_v2.csv -nthreads ${threads}
     #tck2connectome -force -zero_diagonal -scale_length -stat_edge mean mr_track_global_1e9.tck nodes_\${im}.mif.gz \
     #            mr_connectome_global1e9_\${im}_length.csv -nthreads ${threads}
     #3-7: FA MD M0 AD RD
        for dti in FA MD AD RD
        do
     tck2connectome -force -zero_diagonal -stat_edge mean -scale_file mr_track_1M_SIFT_mean_\${dti}.csv \
                   -nthreads ${threads} mr_track_1M_SIFT.tck nodes_\${im}.mif.gz \
                   mr_connectome_sift_1M_\${im}_\${dti}.csv
     #tck2connectome -force -zero_diagonal -stat_edge mean -scale_file mr_track_2M_SIFT_mean_\${dti}.csv \
     #             -nthreads ${threads} mr_track_global_1e9.tck nodes_\${im}.mif.gz \
     #              mr_connectome_global1e9_\${im}_\${dti}.csv
        done
     done
  ####################################################################################################################################
# END OF TRACTOGRAPHY    ######################################################################################################################################
#done
#### COPY ALL THE FILES TO SCRATCH ####
# cp -rfv ../dwi $ABCD/fs/${s}/
#######################################################################
# pigz#
pigz --best -b 1280 -f -v -T -p ${threads} *mif
pigz --best -b 1280 -f -v -T -p ${threads} *nii
# cp -rfv /tmp/${s}/ $ABCD/fs/${s}
# cp -rfv /tmp/sub-\$subjid/ses-baselineYear1Arm1/dwi/ \
#         $ABCD/fs/\`head -n 1 /tmp/tmp_${s}_t1name\`
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
n_split=$((128*8))
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
#SBATCH --ntasks-per-node 8            # Total # of mpi tasks
#SBATCH -t 1:00:00        # Run time (hh:mm:ss)
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

#sbatch $launch_script
done
