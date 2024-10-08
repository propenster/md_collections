#!/bin/sh


ENV_NAME=lysozome-in-water
ENV_EXPORT_FILE_NAME=environment
GMX=gmx
DEFAULT_FORCE_FIELD=oplsaa
MOLECULE_FILE_NAME=1aki
OUTPUT_DIR=output
PDB_DOWNLOAD="https://files.rcsb.org/download/"$MOLECULE_FILE_NAME".pdb"
PDB=$MOLECULE_FILE_NAME".pdb"


SYSTEM_POSITION_IN_BOX=c
SYSTEM_DISTANCE_FROM_BOX_EDGE=1.0
BOX_TYPE=cubic

IONS_FILE_NAME=ions
OPLSAA_MDP=http://www.mdtutorials.com/gmx/lysozyme/Files/$IONS_FILE_NAME".mdp"

MINIM_FILE_NAME=minim
MINIM_FILE_DOWNLOAD_URL=http://www.mdtutorials.com/gmx/lysozyme/Files/$MINIM_FILE_NAME".mdp"

ENERGY_MINIMIZATION_FILE_NAME=em
PE_RESULT_FILE_NAME=potential
XM_GRACE_PACKAGE_NAME=grace
TEMPERATURE_RESULT_FILE_NAME=temperature
PRESSURE_RESULT_FILE_NAME=pressure
NVT_MDP_FILE_NAME=nvt
NVT_MDP_FILE_DOWNLOAD_URL=http://www.mdtutorials.com/gmx/lysozyme/Files/$NVT_MDP_FILE_NAME".mdp"


echo 'Running molecular simulation with parameters'
echo 'ENV_NAME: '$ENV_NAME
echo 'ENV_EXPORT_FILE_NAME: '$ENV_EXPORT_FILE_NAME
echo 'GMX: '$GMX
echo 'DEFAULT_FORCE_FIELD: '$DEFAULT_FORCE_FIELD
echo 'MOLECULE_FILE_NAME: '$MOLECULE_FILE_NAME
echo 'OUTPUT_DIR: '$ENV_NAME
echo 'PDB_DOWNLOAD: '$PDB_DOWNLOAD
echo 'PDB: '$PDB
echo 'SYSTEM_POSITION_IN_BOX: '$SYSTEM_POSITION_IN_BOX
echo 'SYSTEM_DISTANCE_FROM_BOX_EDGE: '$SYSTEM_DISTANCE_FROM_BOX_EDGE
echo 'BOX_TYPE: '$BOX_TYPE
echo 'IONS_FILE_NAME: '$IONS_FILE_NAME
echo 'OPLSAA_MDP: '$OPLSAA_MDP
echo 'MINIM_FILE_NAME: '$MINIM_FILE_NAME
echo 'MINIM_FILE_DOWNLOAD_URL: '$MINIM_FILE_DOWNLOAD_URL
echo 'ENERGY_MINIMIZATION_FILE_NAME: '$ENERGY_MINIMIZATION_FILE_NAME
echo 'PE_RESULT_FILE_NAME: '$PE_RESULT_FILE_NAME
echo 'XM_GRACE_PACKAGE_NAME: '$XM_GRACE_PACKAGE_NAME

echo 'TEMPERATURE_RESULT_FILE_NAME: '$TEMPERATURE_RESULT_FILE_NAME
echo 'PRESSURE_RESULT_FILE_NAME: '$PRESSURE_RESULT_FILE_NAME
echo 'NVT_MDP_FILE_NAME: '$NVT_MDP_FILE_NAME




#create dirs
if [ -d "$OUTPUT_DIR" ]; then
    echo "Directory already exists."
else
    echo "Directory does not exist. Creating now..."
    mkdir -p "$OUTPUT_DIR"
    echo "Directory created."
fi

#STEP 0 - FETCH/DOWNLOAD THE PROTEIN and other FILEs...
echo 'Dowloading PDB file: '$PDB
wget $PDB_DOWNLOAD -O $PDB
echo 'Downloading MDP file that we will later need for the Ionization step... Step 3 - Adding Ions: ' $OPLSAA_MDP
wget $OPLSAA_MDP -O $IONS_FILE_NAME".mdp"
echo 'Downloading minim.MDP file that we will later need for the Energy minimization step... Step 4: ' $MINIM_FILE_DOWNLOAD_URL
wget $MINIM_FILE_DOWNLOAD_URL -O $MINIM_FILE_NAME".mdp"

echo 'Downloading nvt.mdp file that we will later need for the Equilibriation step...'
wget $NVT_MDP_FILE_DOWNLOAD_URL -O $NVT_MDP_FILE_NAME".mdp"

#INSTALLING SYSTEM SOFTWARE NEEDED...e.g XmGrace
echo 'Installing XmGrace: ...system software needed for plotting the potential energy graph after energy minimization'
if dpkg -l | grep -q "^ii  $XM_GRACE_PACKAGE_NAME "; then
    echo "$XM_GRACE_PACKAGE_NAME is already installed."
else
    echo "$XM_GRACE_PACKAGE_NAME is not installed. Installing now..."
    sudo apt-get update
    sudo apt-get install -y "$XM_GRACE_PACKAGE_NAME"
fi
echo 'Installing libarchive-dev'
if dpkg -l | grep -q "^ii  libarchive-dev "; then
    echo "libarchive-dev is already installed."
else
    echo "libarchive-dev is not installed. Installing now..."
    sudo apt-get update
    sudo apt-get install -y "libarchive-dev"
fi

echo 'Installing gromacs on the system'
if dpkg -l | grep -q "^ii  gromacs "; then
    echo "gromacs is already installed."
else
    echo "gromacs is not installed. Installing now..."
    sudo apt-get update
    sudo apt-get install -y "gromacs"
fi



#conda activate $ENV_NAME


#setup a new CONDA env
echo 'Setting up a conda environment'

# #conda config --set solver classic
source ~/miniconda3/etc/profile.d/conda.sh
#conda install -n base conda-libmamba-solver --solver=classic
if conda info --envs | grep -q "^$ENV_NAME"; then
    echo "Environment $ENV_NAME already exists. Activating it..."
    conda activate $ENV_NAME
else
    echo "Creating new environment: $ENV_NAME"
    # Create the environment
    conda create --name $ENV_NAME -y

    # Activate the new environment
    conda activate $ENV_NAME

    # Install GROMACS and other packages
    echo "Installing GROMACS and required libraries..."
    # conda install -y conda-forge::gromacs
    # conda install -y conda-forge/label/broken::gromacs

    # Install additional libraries
    conda install -y numpy pandas matplotlib jupyterlab

    # Export the environment
    echo "Exporting the environment to $ENV_EXPORT_FILE_NAME.yml"
    conda env export --name $ENV_NAME > "$ENV_EXPORT_FILE_NAME.yml"
fi


#STEP 0.1 - Clean up input, do QC, remove crystallized bounded WATER (HOH) molecules... grep... e.g grep -v HOH input/1aki.pdb > input/1aki_cleaned.pdb
grep -v HOH $PDB > $MOLECULE_FILE_NAME"_cleaned.pdb"

#STEP 1.  Generate Topology for the molecule using gmx pdb2gmx tool. N.B: You must also choose a FORCE-field for this md... 
$GMX pdb2gmx -f $MOLECULE_FILE_NAME"_cleaned.pdb" -o $OUTPUT_DIR/$MOLECULE_FILE_NAME"_processed.gro" -ff $DEFAULT_FORCE_FIELD -water spce

mv *.top *.itp $OUTPUT_DIR


#STEP 2. Define a box and Solvate... We define/create the box where we want to mix our molecules...i.e protein inside water plus 
#STEP 2.1 Define the box dimensions using the editconf module. e.g gmx editconf -f output/1aki_processed.gro -o 1aki_newbox.gro -c -d 1.0 -bt cubic
$GMX editconf -f $OUTPUT_DIR/$MOLECULE_FILE_NAME"_processed.gro" -o $OUTPUT_DIR/$MOLECULE_FILE_NAME"_newbox.gro" -$SYSTEM_POSITION_IN_BOX -d $SYSTEM_DISTANCE_FROM_BOX_EDGE -bt $BOX_TYPE

#STEP 2.2 Fill the box with water using the solvate module (formerly called genbox). e.g gmx solvate -cp output/1aki_newbox.gro -cs spc216.gro -o 1ak1_solv.gro -p output/topol.top
$GMX solvate -cp $OUTPUT_DIR/$MOLECULE_FILE_NAME"_newbox.gro" -cs spc216.gro -o $OUTPUT_DIR/$MOLECULE_FILE_NAME"_solv.gro" -p $OUTPUT_DIR/"topol.top"


#STEP 3. Adding Ions
#Ater solvating the system, if the system has a NET-positive charge i.e e.g qtot +8 (based on it's AA composition)... Since life does not exist at a net-positive charge, we must add ions to our system
#We add ions using the genion module of gromacs {genion goes through the topol.top nd replaces water moles with ions that I propenster specify)... genion's input is called runInput file a.k.a ions.tpr {tpr cont all params for all atoms in the system } To produce a .tpr file with grompp, we will need an additional input file, with the extension .mdp (molecular dynamics parameter file); grompp will assemble the parameters specified in the .mdp file with the coordinates and topology information to generate a .tpr file.

#STEP 3.1 - Assemble our .tpr file... e.g gmx grompp -f ions.mdp -c output/1aki_solv.gro -p output/topol.top -o ions.tpr
$GMX grompp -f $IONS_FILE_NAME".mdp" -c $OUTPUT_DIR/$MOLECULE_FILE_NAME"_solv.gro" -p $OUTPUT_DIR/"topol.top" -o $OUTPUT_DIR/$IONS_FILE_NAME".tpr"

#STEP 3.2 - Now we have an atomic-level description of our system in binary file ions.tpr, we can pass this file to genion to add ions
#e.g - gmx genion -s ions.tpr -o 1AKI_solv_ions.gro -p topol.top -pname NA -nname CL -neutral
$GMX genion -s $OUTPUT_DIR/$IONS_FILE_NAME".tpr" -o $OUTPUT_DIR/$MOLECULE_FILE_NAME"_solv_ions.gro" -p $OUTPUT_DIR/"topol.top" -pname NA -nname CL -neutral



#STEP 4 - Energy Minimization
#The solvated, electroneutral system is now assembled. Before we can begin dynamics, we must ensure that the system has no steric clashes or inappropriate geometry. The structure is relaxed through a process called energy minimization (EM).

#STEP 4.1 - Assemble the binary input (i.e em.tpr) using grompp using this input parameter file: we let it output em.tpr in the current dir not the output dir
#e.g gmx grompp -f minim.mdp -c 1AKI_solv_ions.gro -p topol.top -o em.tpr
echo 'running GROMPP'
$GMX grompp -f $MINIM_FILE_NAME".mdp" -c $OUTPUT_DIR/$MOLECULE_FILE_NAME"_solv_ions.gro" -p $OUTPUT_DIR/"topol.top" -o $ENERGY_MINIMIZATION_FILE_NAME".tpr"

#STEP 4.2 - We are now ready to invoke mdrun to carry out the EM:
#e.g gmx mdrun -v -deffnm em
echo 'running mdrun now'
$GMX mdrun -v -deffnm $ENERGY_MINIMIZATION_FILE_NAME
#mdrun generates 4 files: em.log: ASCII-text log file of the EM process em.edr: Binary energy file em.trr: Binary full-precision trajectory em.gro: Energy-minimized structure

# There are two very important factors to evaluate to determine if EM was successful. The first is the potential energy (printed at the end of the EM process, even without -v). Epot should be negative, and (for a simple protein in water) on the order of 105-106, depending on the system size and number of water molecules. The second important feature is the maximum force, Fmax, the target for which was set in minim.mdp - "emtol = 1000.0" - indicating a target Fmax of no greater than 1000 kJ mol-1 nm-1. It is possible to arrive at a reasonable Epot with Fmax > emtol. If this happens, your system may not be stable enough for simulation. Evaluate why it may be happening, and perhaps change your minimization parameters (integrator, emstep, etc).

# Let's do a bit of analysis. The em.edr file contains all of the energy terms that GROMACS collects during EM. You can analyze any .edr file using the GROMACS energy module:

#STEP 4.3 - Generate Analysis for the energy changes through the EM process - potential energy graph - item 10 0
#e.g gmx energy -f em.edr -o potential.xvg
echo 'Generate Analysis for the energy changes through the EM process - potential energy graph'
$GMX energy -f $ENERGY_MINIMIZATION_FILE_NAME".edr" -o $PE_RESULT_FILE_NAME".xvg"

#STEP 4.3b - Plot Generate Analysis for the temperature graph - item 31 0
#e.g gmx energy -f em.edr -o temperature.xvg
echo 'Generate Analysis for the temperature changes through the EM process - temperature graph'
$GMX energy -f $ENERGY_MINIMIZATION_FILE_NAME".edr" -o $TEMPERATURE_RESULT_FILE_NAME".xvg"

#STEP 4.3c - Plot Generate Analysis for the pressure graph - item 11
#e.g gmx energy -f em.edr -o pressure.xvg
echo 'Generate Analysis for the pressure changes through the EM process - pressure graph'
$GMX energy -f $ENERGY_MINIMIZATION_FILE_NAME".edr" -o $PRESSURE_RESULT_FILE_NAME".xvg"



#STEP 4.4 - Plot the potential energy graph - using XmGrace
echo 'Plotting the potential energy graph using XmGrace'
xmgrace potential.xvg -title "Energy Minimization"

#STEP 4.5 - Plot the Temperature Graph - using XmGrace...
echo 'Plotting the temperature graph using XmGrace'
xmgrace temperature.xvg -title "Energy Minimization - Temperature Graph"


#STEP 4.5 - Plot the Pressure Graph - using XmGrace...
echo 'Plotting the pressure graph using XmGrace'
xmgrace pressure.xvg -title "Energy Minimization - Pressure Graph"


#STEP 5 - Equilibriation
#EM ensured that we have a reasonable starting structure, in terms of geometry and solvent orientation. To begin real dynamics, we must equilibrate the solvent and ions around the protein. If we were to attempt unrestrained dynamics at this point, the system may collapse.EM ensured that we have a reasonable starting structure, in terms of geometry and solvent orientation. To begin real dynamics, we must equilibrate the solvent and ions around the protein. If we were to attempt unrestrained dynamics at this point, the system may collapse.

#STEP 5.1 - Assemble our NVT.tpr
#e.g - gmx grompp -f nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr
$GMX grompp -f $NVT_MDP_FILE_NAME".mdp" -c em.gro -r em.gro -p $OUTPUT_DIR/"topol.top" -o $NVT_MDP_FILE_NAME".tpr"

#STEP 5.2 - 
$GMX mdrun -deffnm nvt

#Let's analyze the temperature progression, again using energy:
#Type "16 0" at the prompt to select the temperature of the system and exit.
$GMX energy -f $NVT_MDP_FILE_NAME".edr" -o $TEMPERATURE_RESULT_FILE_NAME"_1.xvg"

#replot temperature graph...
xmgrace temperature.xvg -title "Energy Minimization - Temperature Graph"



