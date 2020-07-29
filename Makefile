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
	./shcalt.R --tau 0.$(1) $$< -o $$@ -l 4 --geo $$(word 2,$$^) > $$@.log 2>&1 && ./h5l.py -t $$< $$@ || rm -f $$@

endef

$(eval $(foreach tau,$(taul),$(call tau-tpl,$(tau))))

define dirl-tpl
ref/t/$(1)/pole.h5: $(zl:%=ref/t/$(1)/z%.h5)
	./pole.R -o $$@ --input $$(wildcard ref/t/$(1)/z*.h5)

endef

$(eval $(foreach dir,$(dirl),$(foreach tau,$(taul),$(call dirl-tpl,$(tau)/$(dir)))))

ref/t/%/upole.h5: $(addprefix ref/t/%/,$(dirl:=/pole.h5))
	mkdir -p $(dir $@)
	./upole.R -o $@ --input $^

define rec-tpl
all: rec/$(1)/vertex.pdf

rec/$(1)/%.h5: cal/$(1)/%.h5 ref/t/10/upole.h5 ref/geo.csv
	mkdir -p $$(dir $$@)
	./ffit.py $$< --poly $$(word 2,$$^) --geo ref/geo.csv -o $$@ > $$@.log 2>&1

rec/$(1)/vertex.pdf: $(zl:%=rec/$(1)/z%.h5)
	./vertex.R -o $$@ --input $$^

endef

$(eval $(foreach d,$(dirl),$(call rec-tpl,$(d))))

# Delete partial files when the processes are killed.
.DELETE_ON_ERROR:
# Keep intermediate files around
.SECONDARY:
