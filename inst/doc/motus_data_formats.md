# Motus Data File Formats #

## 1. File types ##

### 1a. SensorGnome format ###

This format is the default for units running the SensorGnome software (including for the SensorGnome component of the SensorStation). Each file contains individual pulses, gps readings, etc. The data can also be separated for each antenna, as well as for LifeTag detections only (type = ctt).

	Filename format: <site_label>-<receiver_number>-<boot_num>-<datetime><prec>-<type>-<ext>.gz

	Example:	changeMe-3114BBBK2178-000074-2018-01-22T00-29-13.3300T-all.txt.gz
			changeMe-3114BBBK2178-000074-2018-01-22T00-29-13.3300T-ctt.txt.gz

	site_label: user-entered site label (default: changeMe)
	receiver_number: for SensorGnomes, receiver serial number (without the SG prefix, e.g. 3114BBBK2178)
			 for SensorStation, receiver serial number (with the CTT prefix, e.g. CTT-123456789012345)
	boot_num: boot number
	datetime: yyyy-mm-ddTHH:MM:ss.ssss
	prec: single digit representing the clock precision:
		P: clock not set by GPS
		Z: 1 second
		Y: 0.1 second
		X: 0.01 second
		W: 0.001 second
		V: 0.0001 second
		U: 0.00001 second
		T: 0.000001 second
	type: 	all (for all antennae), specific antenna number or ctt (ctt and gps data only)
	ext: extension (typically txt)			
	gz: indicates compressed files (other types of compressions are also supported: bz2, etc.)

### 1b. SensorStation format ###

This format is the default for units running the SensorStation software. Data components are divided separate files: data, node data and gps. Data contains the 32-bit codes interpreted by the CTT dongles, node data contains detections from external node units and gps includes gps readings (only for the base station so far, not for nodes).

	File format: CTT-<serial>-<data_type>.<datetime>.<ext>.gz

	Example :	CTT-867459049219777-data.2019-07-18_191832.csv.gz
			CTT-867459049219777-node-data.2019-07-18_191832.csv.gz
			CTT-867459049219777-gps.2019-07-18_191832.csv.gz

	serial : 15 digit numeric (old) or 12  digit alphanumeric value (new)
	data_type : one of data, raw-data (same as data), data-node or gps
	datetime : <yyyy-MM-dd_HHmmss>
	ext : csv only so far
	gz : indicates compressed files
	
### 1c. Lotek format ###

This is the default format used by Lotek units. Each file contains a header and individual tag detections (not pulses, only putative tags). There are other formats 
available for export from the Lotek units (e.g. binary), but we require the DTA format.

	Filename format: <filename>.DTA

	Example : OldCut0001.DAT
	
	filename : any arbitrary value provided by the user

Filename: the file name is entirely determined by the user and doesn't contain useful information about its content.

## 2. File content ##

### 2a. SensorGnome format ###

The following prefix can be found in sensorgnome files. Files of type *ctt* will only contain T and G prefix.

C : (GPS clock setting precision record: outlines the time the GPS was set (ts), the precision it was set to (prec), and the time elapsed in running the time (elapsed))

	Format : C,<ts>,<prec>,<elapsed>
	Example : C,1528750333.246,1,0.399892479
	Example : C,1561257097.681,6,8.6e-7

G : GPS data entry 

	Format : G,<ts>,<lat>,<lon>,<alt>
	Example : G,1526683597,-23.002083333,118.931118333,736.4
	
p : individual pulse on FunCube Dongles 

	Format : p<port_num>,<ts>,<dfreq>,<sig>,<noise>
	Example : p3,1526683680.8316,0.4,-35.4,-42.56

S : frequency setting record (see fields below for possible name values)

	Format : S,<ts>,<port_num>,<name>,<value>,<rc>,<err>
	Example : S,1366227448.192,5,-m,166.376,0,
	Example : S,946684811.244,3,frequency,151.496,0,
	Example : S,946684811.249,3,gain_mode,1,0,
	Example : S,946684811.25,3,tuner_gain,40.2,0,
	Example : S,946684811.25,3,test_mode,0,0,
	Example : S,946684811.251,3,agc_mode,0,0,

T : LifeTag hit on CTT/CVRX dongle or SensorStation
	
	Format : T<port_num>,<ts>,<tag_code>
	Example : T4,1557450282.889,04452182
	
Fields:

	-m : antenna listing frequency?
	alt : altitude (m)
	dfreq : frequency offset (KHz)
	err : blank on success, else error message (frequency setting)
	freq : nominal frequency
	lat : latitude (degrees)
	lon : longitude (degrees)
	name : arbitrary parameter name
	noise : noise level (dB?)
	port_num : port number (antenna)
	rc : response code (?). E.g. zero if frequency setting succeeded, else non-zero error code
	sig : signal strength (dB)
	tag_code : 32-bit tag code (e.g. LifeTag)
	ts : Unix timestamp (seconds)
	value : arbitrary parameter value
	
### 2b. SensorStation (LifeTag) format ###

SensorStation (LifeTag) files will contain headers specifying their content. No assumptions should be made about the order or the list of  fields included within those files. The formats below are those currently in use at the time of this document.

data (or raw-data) files:

	Format : <Time>,<RadioId>,<TagId>,<TagRSSI>,<NodeId>
	Format : <Time>,<RadioId>,<TagId>,<TagRSSI>,<NodeId>,<Validated>
	
	Example : 2019-07-16 20:18:39.845,3,6161527F,-96,
	
	Time : datetime (UTC) yyyy-MM-dd HH:mm:ss.sss
	RadioId : Port number (numeric). Those ports are saved with a L prefix in the metadata and the data tables
	TagId : tag number (e.g. AF7709D3)
	TagRSSI : Received Signal Strenght Indication
	NodeId : hex ID of the node that originally captured the signal (3-digit for old models. Should be unique in more recent models)
	Validated : 0 or 1 to indicate whether the tag was considered valid by CTT algorithms (details unknown).
	
node-data files: meta information about the nodes

	Format : <Time>,<RadioId>,<NodeId>,<NodeRSSI>,<Battery>,<Celcius>
	Format : <Time>,<RadioId>,<NodeId>,<NodeRSSI>,<Battery>,<Celcius>,<RecordedAt>,<Firmware>,<SolarVolts>,<SolarCurrent>,<CumulativeSolarCurrent>,<Latitude>,<Longitude>
	
	Time : datetime (UTC) yyyy-MM-dd HH:mm:ss.sss when the data was received at the base station
	RadioId : Port number (numeric). Those ports are saved with a L prefix in the metadata and the data tables
	NodeRSSI : Received Signal Strenght Indication (node signal on the base station)
	Battery : battery power level
	Celcius : node temperature
	RecordedAt : datetime (UTC) when the data was recorded on the node
	Firmware : node firmware
	SolarVolts : solar voltage
	SolarCurrent : solar current
	CumulativeSolarCurrent :  cumulative solar current
	Latitude : node latitude
	Longitude : node longitude

gps files: gps readings of the base station

	Format : <recorded at>,<gps at>,<latitude>,<longitude>,<altitude>,<quality>
	Format : <recorded at>,<gps at>,<latitude>,<longitude>,<altitude>,<quality>,<mean lat>,<mean lon>,<n fixes>

	Example : 2019-08-17T03:09:27.458Z,2019-08-17T03:09:26.000Z,38.240977833,-75.1360325,2.7,3

	recorded at : datetime (UTC) yyyy-MM-ddTHH:mm:ss.sssZ
	gps at :  datetime of gps clock (UTC) yyyy-MM-ddTHH:mm:ss.sssZ
	latitude : latitude (degrees)
	longitude : longitude (degrees)
	altitude : altitude (m)
	quality : signal quality (units?)
	mean lat : mean latitude
	mean lon : mean longitude
	n fixes : number of fixes used to calculate mean 
	
	
### 2c. Lotek format ###

Data segment: individual tag detections. We request that users export their DTA file using GMT times, but there is no guarantee. Hopefully, newer versions will format dates as ISO 8601 to include the time zone.

	Format: <Date> <Time>    <Channel>  <Tag ID>    <Antenna>   <Power>
	Example: 06/05/15  12:43:10.6489         0     393    A1+A2+A3+A4     131

