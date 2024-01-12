#!/bin/bash
cat src/tuya_decode.be >> tapp/autoexec.be &&
zip -j -0 tapp/tuya_decode.tapp tapp/autoexec.be &&
rm tapp/autoexec.be
