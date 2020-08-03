JUNO:=/cvmfs/juno.ihep.ac.cn/sl6_amd64_gcc830/Pre-Release/J20v1r0-Pre2/offline/Simulation/DetSimV2/DetSimOptions/data

zl:=$(shell seq -17000 500 17000)
taul:=01 02 05 10 20 50
dirl:=up down transverse
JOBS:=4

.PHONY: all
all: $(taul:%=ref/t/%/upole.h5)

# 262144 is a magic number to map 300000 in the .csv to 37856 in detector simulation
ref/geo.csv: $(JUNO)/PMTPos_Acrylic_with_chimney.csv $(JUNO)/3inch_pos.csv
	mkdir -p $(dir $@)
	cut -d' ' -f1,5,6 < $< > $@
	cat $(word 2,$^) >> $@

cal/%.h5: cal/%.root
	./rdet.py $^ -o $@ -z $(subst z,,$(basename $(notdir $@)))

define tau-tpl
ref/t/$(1)/%.h5: cal/%.h5 ref/geo.csv
	mkdir -p $$(dir $$@) && rm -f $$@
	while ! ./shcalt.R --tau 0.$(1) $$< -o $$@ -l 4 --geo $$(word 2,$$^); do sleep 5; done > $$@.log 2>&1

endef

$(eval $(foreach tau,$(taul),$(call tau-tpl,$(tau))))

ref/%/pole.h5: $(addprefix ref/%/z,$(zl:=.h5))
	./pole.R -o $@ --input $^

ref/%/upole.h5: $(addprefix ref/%/,$(dirl:=/pole.h5))
	mkdir -p $(dir $@)
	./upole.R -o $@ --input $^

rec/0/%.h5: cal/%.h5 ref/t/10/upole.h5 ref/geo.csv
	mkdir -p $(dir $@)
	./ffit.py $< --poly $(word 2,$^) --geo ref/geo.csv -o $@ > $@.log 2>&1

rec/o/%/vertex.h5: rec/0/%/offset.csv $(addprefix rec/o/%/z,$(zl:=.h5)) 
	./vertex.R -o $@ --input $(wordlist 2,999,$^) --offset $<

# default rec/
rec/0/%/vertex.h5: $(addprefix rec/0/%/z,$(zl:=.h5))
	./vertex.R -o $@ --input $^

%/offset.csv: %/up/vertex.h5 %/down/vertex.h5 %/transverse/vertex.h5
	./offset.R --up $< --down $(word 2,$^) --transverse $(word 3,$^) -o $@

%/up/offset.csv: %/offset.csv
	echo 0 0 `cat $^` > $@
%/down/offset.csv: %/offset.csv
	echo 0 0 -`cat $^` > $@
%/transverse/offset.csv: %/offset.csv
	echo 0 `cat $^` 0 > $@

define otau-tpl
ref/o/t/$(1)/$(2)/%.h5: cal/$(2)/%.h5 ref/geo.csv rec/0/$(2)/offset.csv
	mkdir -p $$(dir $$@) && rm -f $$@
	while ! ./shcalt.R --tau 0.$(1) $$< -o $$@ -l 4 --geo $$(word 2,$$^) --offset rec/0/$(2)/offset.csv; do sleep 5; done > $$@.log 2>&1

endef

$(eval $(foreach d,$(dirl),$(foreach tau,$(taul),$(call otau-tpl,$(tau),$(d)))))

all: $(dirl:%=rec/o/%/vertex.h5)

rec/o/%.h5: cal/%.h5 ref/o/t/10/upole.h5 ref/geo.csv
	mkdir -p $(dir $@)
	./ffit.py $< --poly $(word 2,$^) --geo ref/geo.csv -o $@ > $@.log 2>&1

rec/s/%.pdf: ref/o/t/10/%.h5 ref/o/t/10/upole.h5
	mkdir -p $(dir $@)
	./match.py $< -o $@ --poly $(word 2,$^)

# Delete partial files when the processes are killed.
.DELETE_ON_ERROR:
# Keep intermediate files around
.SECONDARY:
