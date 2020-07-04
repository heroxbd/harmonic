JUNO:=/cvmfs/juno.ihep.ac.cn/sl6_amd64_gcc830/Pre-Release/J20v1r0-Pre2/offline/Simulation/DetSimV2/DetSimOptions/data

zl:=$(shell seq -17000 500 17000)
taul:=01 05 10 20 50
JOBS:=4

.PHONY: all
all: $(taul:%=ref/t/%/pole.pdf)

# 262144 is a magic number to map 300000 in the .csv to 37856 in detector simulation
ref/geo.csv: $(JUNO)/PMTPos_Acrylic_with_chimney.csv $(JUNO)/3inch_pos.csv
	mkdir -p $(dir $@)
	cut -d' ' -f1,5,6 < $< > $@
	awk '{print $$1 - 262144  " "  $$2 " " $$3}' < $(word 2,$^) >> $@

cal/%.h5: cal/%.root
	./rdet.py $^ -o $@ -z $(subst z,,$(basename $(notdir $@)))

define tau-tpl
ref/t/$(1)/%.h5: cal/%.h5 ref/geo.csv
	mkdir -p $$(dir $$@) && rm -f $$@
	./shcalt.R --tau 0.$(1) $$< -o $$@ -l 4 --geo $$(word 2,$$^) > $$@.log 2>&1 && ./h5l.py -t $$< $$@ || rm -f $$@

ref/t/$(1)/pole.pdf: $(zl:%=ref/t/$(1)/z%.h5)
	./pole.R -o $$@ --input $$(wildcard ref/t/$(1)/z*.h5)

endef

$(eval $(foreach tau,$(taul),$(call tau-tpl,$(tau))))

ref/q/%.h5: tt/cal/%.h5
	mkdir -p $(dir $@) && rm -f $@
	./shcalq.R $^ -j $(JOBS) -o $@ -l 9

# Delete partial files when the processes are killed.
.DELETE_ON_ERROR:
# Keep intermediate files around
.SECONDARY:
