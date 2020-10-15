#!/bin/bash

###
# This script performs partial volume correction for a predefined list of thalamic VOIs
# The end product is a nifti file in which each VOI has been eroded until its volume is less than 50% of the original volume
###

subdir=/Users/Orchid/Desktop/2FA_Project/Data

sublist=$(ls ${subdir}) # | head -1) # Tells the script which subjects to run. Each subject takes about 8 minutes and 45 seconds to run

for subject in ${sublist}; do

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

	# Now that all the proper VOIs are made, we go through each one and reduce it to less than half of its original volume
	# This step takes about 7.5 minutes

	thalvois=$(ls ${thaldir})
	echo -e -n "\nReducing size of VOIs."

	for voi in ${thalvois}; do
		orig_vol=$(fslstats ${thaldir}/${voi} -V) # Gets the volume of the original VOI
		orig_vol=$(echo ${orig_vol} | cut -f1 -d" ") # Takes the number from above and removes FSL's formatting
		final_vol=${orig_vol} # Creates the final_vol variable
		vol_ratio=$(echo "scale=3 ; ${final_vol} / ${orig_vol}" | bc) # Uses the bc calculator to establish the ratio of the volumes (starts at 1)
		cp ${thaldir}/${voi} ${thaldir}/ero_${voi} # Makes the VOI that is going to be eroded

		while (( $(echo "${vol_ratio} > 0.5" | bc -l) )); do # Checks to see if the volume ratio is greater than .5 using the bc calculator
			fslmaths ${thaldir}/ero_${voi} -kernel sphere 1 -ero ${thaldir}/ero_${voi} # Does the actual eroding
			final_vol=$(fslstats ${thaldir}/ero_${voi} -V) # Gets the volume of the eroded VOI
			final_vol=$(echo ${final_vol} | cut -f1 -d" ") # Takes the number from above and removes FSL's formatting
			vol_ratio=$(echo "scale=3 ; ${final_vol} / ${orig_vol}" | bc) # Sets vol_ratio as the new ratio of the volumes
			echo -n .
		done

		# Now we create a text file with the VOI number and the volume ratio (for later reporting)

		voi_number=$(echo ${voi} | cut -f1 -d".")
		echo "${voi_number},${vol_ratio}" >> ${subdir}/${subject}/thal_voi_vols.txt

		# Now we remove the original VOI and leave only the eroded one
		rm ${thaldir}/${voi}
	done

	# Now that all the VOIs are eroded, we add them together to make the final image
	# This step takes about 15 seconds

	echo -e -n "\nCreating final image."

	cd ${thaldir}

	firstvoi=$(ls ${thaldir} | head -1) # Saves the first VOI in the list so FSL can use it as the starting point
	thalvois=$(ls ${thaldir} | tail -n+2) # Saves everything else in the list as a seperate variable

	for voi in ${thalvois}; do # Takes all the VOIs except the first and copies them into a text file with -add commands in between
		echo -n "-add " >> inputs.txt
		echo -n "${voi} " >> inputs.txt
		echo -n .
	done

	fslmaths ${firstvoi} $(cat inputs.txt) ${subject}_eroded_vois.nii # Adds the VOIs together and saves the final product
	rm inputs.txt # Removes the text file that was used for fslmaths
	rm ero* # Gets rid of all the eroded VOIs
	gunzip ${subject}_eroded_vois.nii.gz

	mv ${thaldir}/${subject}_eroded_vois.nii ${subdir}/${subject}/ # Moves the final image up to the subject folder
	rm -rf ${thaldir} # Removes the thalamus folder

	echo -e "\n${subject} is done!"

done

echo
echo ---
echo All done!
echo ---
