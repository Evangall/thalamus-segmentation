#!/bin/bash

###
# A modified version of PVC.sh that should spit out VOI volumes for each subject
###

subdir=/Users/Orchid/Desktop/2FA_Project/Data

sublist=$(ls ${subdir}) # | head -1) # Tells the script which subjects to run. 

for subject in ${sublist}; do

	# First we print the subject name on the big output sheet
	echo "${subject}" >> ${subdir}/thal_voi_volumes.txt

	# First we cd into each subject directory, make a folder for the thalamic VOIs, and clean up stuff from previous runs (if applicable)

	cd ${subdir}/${subject}
	orig=${subdir}/${subject}/${subject}_thalamus.nii
	mkdir -p ${subdir}/${subject}/thalamic_vois/
	thaldir=${subdir}/${subject}/thalamic_vois
	rm ${thaldir}/*
	rm ${subdir}/${subject}/thal_voi_vols.txt
	echo -n Splitting VOIs for ${subject}.

	# Then we split the original thalamic image into individual VOIs and delete the VOIs that are empty
	# This step takes about 1 minute

	# Left hemisphere...
	for i in {8103..8133}; do # The list of left VOIs
		fslmaths ${orig} -thr ${i} -uthr ${i} ${thaldir}/${i}.nii # Split each VOI
		mean=$(fslstats ${thaldir}/${i}.nii.gz -m) # Check the mean intensity (note LOWERCASE m)
		if [ ${mean} == 0.000000 ]; then # If the mean intensity is 0...
			rm ${thaldir}/${i}.nii.gz # ...Delete it
		fi
		echo -n .
	done

	# Right hemisphere
	for j in {8203..8233}; do # The list of right VOIs
		fslmaths ${orig} -thr ${j} -uthr ${j} ${thaldir}/${j}.nii # Split each VOI
		mean=$(fslstats ${thaldir}/${j}.nii.gz -m) # Check the mean intensity (note LOWERCASE m)
		if [ ${mean} == 0.000000 ]; then # If the mean intensity is 0...
			rm ${thaldir}/${j}.nii.gz # ...Delete it
		fi
		echo -n .
	done

	# Now that all the proper VOIs are made, we go through each one and find the volume

	thalvois=$(ls ${thaldir})
	echo -e -n "\nCalculating VOI volumes."

	for voi in ${thalvois}; do
		orig_vol=$(fslstats ${thaldir}/${voi} -V) # Gets the volume of the original VOI
		orig_vol=$(echo ${orig_vol} | cut -f1 -d" ") # Takes the number from above and removes FSL's formatting

		# Now we create a text file with the VOI number and the corresponding volume

		voi_number=$(echo ${voi} | cut -f1 -d".")
		echo "${voi_number},${orig_vol}" >> ${subdir}/thal_voi_volumes.txt

	done

	rm -rf ${thaldir} # Removes the thalamus folder

	echo -e "\n${subject} is done!"

done

echo
echo ---
echo All done!
echo ---
