#!/bin/bash

list=$1
threads=64
#threadsX2=$((${threads}*2))

adni=/lus/theta-fs0/projects/AD_Brain_Imaging/anal/adni

CMD_batch=/lus/theta-fs0/projects/AD_Brain_Imaging/anal/adni/adni_on_alcf/job/cmd1.batch.trac.${list}
rm -rf $CMD_batch

#######################################################################################################
cat<<EOC >$CMD_batch
#!/bin/bash
#COBALT -t 360
#COBALT -n 202
#COBALT --attrs mcdram=cache:numa=quad
#COBALT -A AD_Brain_Imaging
echo start............................................
#export n_nodes=$COBALT_JOBSIZE
#export n_mpi_ranks_per_node=202
#export n_mpi_ranks=202
#export n_openmp_threads_per_rank=64
#export n_hyperthreads_per_core=4
EOC

#######################################################################################################
i=1
for s in `cat /lus/theta-fs0/projects/AD_Brain_Imaging/anal/adni/fs/\$list`
do
#s=`echo $SUBJECT | egrep -o '[0-9]{8}'`
CMD=/lus/theta-fs0/projects/AD_Brain_Imaging/anal/adni/adni_on_alcf/job/cmd1.trac.${s}
rm -rf $CMD

CMD_sub=/lus/theta-fs0/projects/AD_Brain_Imaging/anal/adni/adni_on_alcf/job/cmd1_sub.trac.${s}
rm -rf $CMD_sub


SUBJECT=${s}
#echo ${SUBJECT}

cat<<EOC >$CMD
#!/bin/bash
source ~/.bashrc
workingdir=/lus/theta-fs0/projects/AD_Brain_Imaging/anal/adni/fs/${SUBJECT}/dmri2
echo \$workingdir
mkdir \$workingdir
if [ ! -e \$workingdir ]; then mkdir \$workingdir; fi
cd \$workingdir
pwd
ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=256
#%% 1. setup %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#cp /ifs/scratch/pimri/posnerlab/1anal/adni/data/nii/${s}_*DTI.nii.gz ./dti.nii.gz
#cp /ifs/scratch/pimri/posnerlab/1anal/adni/data/nii/${s}_*DTI.bvec ./dti.bvec
#cp /ifs/scratch/pimri/posnerlab/1anal/adni/data/nii/${s}_*DTI.bval ./dti.bval
#cp /ifs/scratch/pimri/posnerlab/1anal/adni/data/nii/${s}_*DTI.bvec_tp ./dti.bvec_tp
#cp /ifs/scratch/pimri/posnerlab/1anal/adni/data/nii/${s}_*DTI.bval_tp ./dti.bval_tp
#%% 2. DWI processing2-converting nifti to mif%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if [ ! -e mr_fod.mif.gz ];then
    mrconvert dti.nii.gz -force mr_dwi.mif.gz -fslgrad dti.bvec dti.bval -datatype float32 -stride 0,0,0,1 -nthreads 256
fi
#%% 3. denoising
if [ ! -e mr_dwi_denoised.mif.gz ];then
    dwidenoise mr_dwi.mif.gz -force mr_dwi_denoised.mif.gz -nthreads 256
fi
#%% 4. dwipreproc -eddy current
if [ ! -e mr_dwi_denoised_preproc.mif.gz ];then
    dwipreproc -rpe_none -pe_dir PA mr_dwi_denoised.mif.gz -force mr_dwi_denoised_preproc.mif.gz -rpe_none -nthreads 256
fi
#%% 5. mask and bias field correction
if [ ! -e mr_eroded_mask.mif.gz ]; then
     dwi2mask mr_dwi_denoised_preproc.mif.gz - -nthreads 256 | maskfilter - erode -npass 7 -force mr_eroded_mask.mif.gz -nthreads 256
fi
#%% 6. bias field correction
if [ ! -e mr_dwi_denoised_preproc_biasCorr.mif.gz ]; then
     dwibiascorrect mr_dwi_denoised_preproc.mif.gz -force mr_dwi_denoised_preproc_biasCorr.mif.gz -ants -mask mr_eroded_mask.mif.gz -fslgrad dti.bvec dti.bval -nthreads 256
fi
#%% 7. generating b0 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if [ ! -e mr_meanb0.mif.gz ];then
     dwiextract mr_dwi_denoised_preproc_biasCorr.mif.gz - -bzero -nthreads 256 | mrmath - mean -force mr_meanb0.mif.gz -axis 3 -nthreads 256 
fi
#%% 8. upsampling %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for im in mr_dwi_denoised_preproc_biasCorr mr_eroded_mask mr_meanb0;
do 
     if [ ! -e \${im}_upsample.mif.gz ];then
     mrresize \${im}.mif.gz -scale 2.0 -force \${im}_upsample.mif.gz -nthreads 256
     fi
done
#%% 9. dwi2response-subject level %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if [ ! -e response_wm.txt ]; then
    dwi2response dhollander -mask mr_eroded_mask.mif.gz -voxels mr_voxels_eroded.mif.gz mr_dwi_denoised_preproc_biasCorr.mif.gz response_wm.txt response_gm.txt response_csf.txt -force -nthreads 256
fi
#%% FOD%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#% make sure to use "DILATED MASK" for FOD generation
if [ ! -e mr_dilate_mask.mif.gz ];then
    dwi2mask mr_dwi_denoised_preproc_biasCorr.mif.gz - -nthreads 256 | maskfilter - dilate -npass 5 -force mr_dilate_mask.mif.gz -nthreads 256
fi
if [ ! -e WM_FODs.mif.gz ];then
   dwi2fod msmt_csd mr_dwi_denoised_preproc_biasCorr.mif.gz response_wm.txt WM_FODs.mif.gz response_gm.txt gm.mif.gz response_csf.txt csf.mif.gz -mask mr_dilate_mask.mif.gz -force -nthreads 256
fi
if [ ! -e tissueRGB.mif.gz ]; then
   mrconvert WM_FODs.mif.gz - -coord 3 0 -nthreads 256 | mrcat csf.mif.gz gm.mif.gz - tissueRGB.mif.gz -axis 3 -nthreads 256
fi
mrconvert mr_dwi_denoised_preproc_biasCorr.mif.gz mr_dwi_denoised_preproc_biasCorr.nii.gz -force -nthreads 256
mrconvert mr_dilate_mask.mif.gz mr_dilate_mask.nii.gz -force -nthreads 256
dtifit -k mr_dwi_denoised_preproc_biasCorr.nii.gz -o dtifit -m mr_dilate_mask.nii.gz -r dti.bvec -b dti.bval -V
echo "I THINK EVERYTHING IS DONE BY NOW"
EOC

chmod +x $CMD

####################################################################
cat<<EOA >$CMD_sub
#!/bin/bash
#COBALT -t 60
#COBALT -n 1
#COBALT --attrs mcdram=cache:numa=quad
#COBALT -A AD_Brain_Imaging
echo start............................................
#export n_nodes=$COBALT_JOBSIZE
#export n_mpi_ranks_per_node=202
#export n_mpi_ranks=202
#export n_openmp_threads_per_rank=64
#export n_hyperthreads_per_core=4
aprun -n 1 -N 1 -d 1 -j 4 -cc depth -e OMP_NUM_THREADS=256 -cc depth $CMD
EOA
#####################################################################

chmod +x $CMD_sub


echo "aprun -n 1 -N 1 -j 4 -cc depth -e OMP_NUM_THREADS=256 $CMD > cmd1.log.${SUBJECT} &">>$CMD_batch
echo "sleep 0.2">>$CMD_batch
i=$(($i+1))
echo $i
#echo "execute $CMD_sub"

done

echo "wait" >> $CMD_batch
### batch submission

echo $CMD_batch
chmod +x $CMD_batch
echo "qsub $CMD_batch"
#$code/fsl_sub_hpc_2 -s smp,$threads -l /ifs/scratch/pimri/posnerlab/1anal/adni/adni_on_c2b2/job -t $CMD_batch
#$code/fsl_sub_hpc_6 -l /ifs/scratch/pimri/posnerlab/1anal/adni/adni_on_c2b2/job -t $CMD_batch
