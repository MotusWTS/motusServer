# Motus Data File Formats #

## 1. File types ##

### 1a. SensorGnome format ###

This format is the default for units running the SensorGnome software (including for the SensorGnome component of the SensorStation). Each file contains individual pulses, gps readings, etc.

Filename format: <site_label>-<receiver_number>-<boot_num>-<datetime>-<type>-<ext>.gz

Example:	changeMe-3114BBBK2178-000074-2018-01-22T00-29-13.3300T-all.txt.gz
			changeMe-3114BBBK2178-000074-2018-01-22T00-29-13.3300T-ctt.txt.gz

site_label: user-entered site label (default: changeMe)
receiver_number: for SensorGnomes, receiver serial number (without the SG prefix, e.g. 3114BBBK2178)
				 for SensorStation, receiver serial number (with the CTT prefix, e.g. CTT-123456789012345)
boot_num: boot number
datetime: yyyy-mm-ddTHH:MM:ss.ssssT
type: 	Lotek Nanotag data: all (for all antennae), or antenna number. Those files will also contain CTT detections in the old sensorgnome software
		CTT data: ctt data only
ext: extension (typically txt)			
gz: indicates compressed files (other types of compressions are also supported: bz2, etc.)

### 1b. SensorStation format ###

This format is the default for units running the SensorGnome software (including for the SensorGnome component of the SensorStation). Each file contains individual pulses, gps readings, etc.


### 1c. Lotek format ###

This is the default format used by Lotek units. Each file contains a header and individual tag detections (not pulses, only putative tags). There are other formats 
available for export from the Lotek units (e.g. binary), but we require the DTA format.

Filename format: <filename>.DTA

Example: OldCut0001.DAT

Filename: the file name is entirely determined by the user and doesn't contain useful information about its content.

## 2. File content ##

### SensorGnome format ###

The following prefix can be found in sensorgnome files:

p : individual pulse on FunCube Dongles 

	Format: p<ant>,<ts>,<freq_offset>,<sig_strength>
	Example: 

G : GPS data entry 

	Format: G,<ts>,<lat>,<lon>,<alt>
	
S : ?

T : LifeTag hit on CTT/CVRX dongle or SensorStation
	
	Format: T<ant>,<ts>,<tag_code>
	Example: T4,1557450282.889,04452182
	


