# open-LIFU
This repository contains the software for OpenWater's Transcranial Focused Ultrasound Platform. open-LIFU is an ultrasound platform designed to help researchers transmit focused ultrasound beams into subject’s brains, so that those researchers can learn more about how different types of ultrasound beams interact with the neurons in the brain. Unlike other focused ultrasound systems which are aimed only by their placement on the head, open-LIFU uses an array to precisely steer the ultrasound focus to the target location, while its wearable small size allows transmission through the forehead into a precise spot location in the brain even while the patient is moving.

For additional details on open-LIFU, refer to the [wiki](http://162.246.254.83/index.php/Neuromodulation).

## Required Software
1. Download Matlab (2021a) and license
2. Download [K-Wave](http://www.k-wave.org/download.php)
3. Download the [K-Wave alpha functions](http://www.k-wave.org/downloads/kWaveArray_alpha_0.3.zip) and add them to the K-Wave installation folder (specifically we need `kWaveArray.m`)
4. If using Verasonics, install Verasonics software, versions 4.6.2, and request a license. 

## Examples
Example scripts can be found in the [examples](examples) folder. These cover a number of topics, including the initial creation of a database and specification of an ultrasound transducer, as well as the planning and delivery of a treatment.

## API Reference
For a detailed description of the code classes and methods, see the [API Reference](https://github.com/OpenwaterHealth/opw_neuromod_sw/wiki)

## Definitions
* A `Plan` specifies the treatment protocol and how we will compute the transmitted signals to achieve the requested pressures/intensities
* A `System` is a piece of hardware that can deliver a treatment `Solution` via a connected `Transducer`
* A `Transducer` contains the geometry and transmit characteristics of a particular matrix array
* A `Subject` is a person who will receive treatment
* A `Session` is a visit in which a treatment is planned and delivered, including the position of the `Transducer` and the `Target` location within the `Subject`'s brain `Volume`
* A `Solution` contains the computed signals that a `Transducer` must generate to treat a `Target` in the `Subject` according to the `Plan`
* A `Volume` contains the MRI data for the subject, which may be used in computing a `Solution`
* A `Target` is a position within a `Subject`'s brain

## Data Storage Model
When a database is created, data are stored in a hierarchy of folders that looks like this. 
```
'C:/Users/pjh7/Documents/db\
     ￨ plans\
     ￨ ￨ plans.json
     ￨ ￨ <plan>\
     ￨ ￨ ￨ <plan>.json
     ￨ subjects\
     ￨ ￨ subjects.json
     ￨ ￨ <subject>\
     ￨ ￨ ￨ <subject>.json
     ￨ ￨ ￨ sessions\
     ￨ ￨ ￨ ￨ <session>\
     ￨ ￨ ￨ ￨ ￨ <session>.json
     ￨ ￨ ￨ ￨ ￨ solutions\
     ￨ ￨ ￨ ￨ ￨ ￨ <plan>\
     ￨ ￨ ￨ ￨ ￨ ￨ ￨ <target>.analysis.json
     ￨ ￨ ￨ ￨ ￨ ￨ ￨ <target>.json
     ￨ ￨ ￨ ￨ ￨ ￨ ￨ <target>.mat
     ￨ ￨ ￨ volumes\
     ￨ ￨ ￨ ￨ <volume1>.json
     ￨ ￨ ￨ ￨ <volume1>.nii
     ￨ ￨ ￨ ￨ <volume2>.json
     ￨ ￨ ￨ ￨ <volume2>.nii
     ￨ systems\
     ￨ ￨ systems.json
     ￨ ￨ connected_system.txt
     ￨ ￨ <system>\
     ￨ ￨ ￨ <system>.json
     ￨ transducers\
     ￨ ￨ transducers.json
     ￨ ￨ connected_transducer.txt
     ￨ ￨ <transducer>\
     ￨ ￨ ￨ <transducer>.json
```

## License
open-tFUS is licensed under the GNU Affero General Public License v3.0. See [LICENSE](LICENSE) for details.

## Investigational Use Only
CAUTION - Investigational device. Limited by Federal (or United States) law to investigational use. open-LIFU has *not* been evaluated by the FDA and is not designed for the treatment or diagnosis of any disease. It is provided AS-IS, with no warranties. User assumes all liability and responsibility for identifying and mitigating risks associated with using this software.
