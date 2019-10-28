#!/bin/bash
#path=$1
#sleep 1
#cd $path
echo "This bash script will create table from ?.stats files"
echo "Written by Jamaan Alghamdi & Dr. Vanessa Sluming"
echo "University of Liverpool"
echo "jamaan.alghamdi@gmail.com"
echo "http://www.easyneuroimaging.com"
echo "20/12/2010"

#export FREESURFER_HOME=/work/03263/jcha9928/stampede2/app/freesurfer_dev/freesurfer
#sleep 1
#source $FREESURFER_HOME/SetUpFreeSurfer.sh
#sleep 1



#export SUBJECTS_DIR=$1
SUBJECTS_DIR=/scratch/03263/jcha9928/data/ABCD/data_bids_derivatives/freesurfer
list=`cat $1`
target=/scratch/03263/jcha9928/data/ABCD/data_bids_derivatives/freesurfer_group
cd $target
asegstats2table_abcd --subjects $list --meas volume --skip --statsfile wmparc.stats --all-segs --tablefile wmparc_stats.txt
asegstats2table_abcd --subjects $list --meas volume --skip --tablefile aseg_stats.txt
aparcstats2table_abcd --subjects $list --hemi lh --meas volume --skip --tablefile aparc_volume_lh.txt
aparcstats2table_abcd --subjects $list --hemi lh --meas thickness --skip --tablefile aparc_thickness_lh.txt
aparcstats2table_abcd --subjects $list --hemi lh --meas area --skip --tablefile aparc_area_lh.txt
aparcstats2table_abcd --subjects $list --hemi lh --meas meancurv --skip --tablefile aparc_meancurv_lh.txt
aparcstats2table_abcd --subjects $list --hemi rh --meas volume --skip --tablefile aparc_volume_rh.txt
aparcstats2table_abcd --subjects $list --hemi rh --meas thickness --skip --tablefile aparc_thickness_rh.txt
aparcstats2table_abcd --subjects $list --hemi rh --meas area --skip --tablefile aparc_area_rh.txt
aparcstats2table_abcd --subjects $list --hemi rh --meas meancurv --skip --tablefile aparc_meancurv_rh.txt
aparcstats2table_abcd --hemi lh --subjects $list --parc aparc.a2009s --meas volume --skip -t lh.a2009s.volume.txt
aparcstats2table_abcd --hemi lh --subjects $list --parc aparc.a2009s --meas thickness --skip -t lh.a2009s.thickness.txt
aparcstats2table_abcd --hemi lh --subjects $list --parc aparc.a2009s --meas area --skip -t lh.a2009s.area.txt
aparcstats2table_abcd --hemi lh --subjects $list --parc aparc.a2009s --meas meancurv --skip -t lh.a2009s.meancurv.txt
aparcstats2table_abcd --hemi rh --subjects $list --parc aparc.a2009s --meas volume --skip -t rh.a2009s.volume.txt
aparcstats2table_abcd --hemi rh --subjects $list --parc aparc.a2009s --meas thickness --skip -t rh.a2009s.thickness.txt
aparcstats2table_abcd --hemi rh --subjects $list --parc aparc.a2009s --meas area --skip -t rh.a2009s.area.txt
aparcstats2table_abcd --hemi rh --subjects $list --parc aparc.a2009s --meas meancurv --skip -t rh.a2009s.meancurv.txt
aparcstats2table_abcd --hemi lh --subjects $list --parc BA --meas volume --skip -t lh.BA.volume.txt
aparcstats2table_abcd --hemi lh --subjects $list --parc BA --meas thickness --skip -t lh.BA.thickness.txt
aparcstats2table_abcd --hemi lh --subjects $list --parc BA --meas area --skip -t lh.BA.area.txt
aparcstats2table_abcd --hemi lh --subjects $list --parc BA --meas meancurv --skip -t lh.BA.meancurv.txt
aparcstats2table_abcd --hemi rh --subjects $list --parc BA --meas volume --skip -t rh.BA.volume.txt
aparcstats2table_abcd --hemi rh --subjects $list --parc BA --meas thickness --skip -t rh.BA.thickness.txt
aparcstats2table_abcd --hemi rh --subjects $list --parc BA --meas area --skip -t rh.BA.area.txt
aparcstats2table_abcd --hemi rh --subjects $list --parc BA --meas meancurv --skip -t rh.BA.meancurv.txt
