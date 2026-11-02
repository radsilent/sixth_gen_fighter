// Copyright (c) 2026 Vector Stream Systems LLC. All rights reserved.
// SPDX-License-Identifier: LicenseRef-Proprietary

package SixthGenFighterInterfaces {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import MBEstudio::*;

    /* ------------------------------------------------------------ */
    /* Enumerations                                                  */
    /* ------------------------------------------------------------ */

    enum def StoreStatus {
        doc /* State of one internal weapon station as reported to the mission computer. */
        enum empty;
        enum loaded;
        enum armed;
        enum released;
        enum hung;
    }

    enum def CycleMode {
        doc /* Operating cycle of the adaptive cycle engine: third stream open for range, closed for thrust. */
        enum highBypass;
        enum highThrust;
        enum 'transition';
    }

    /* ------------------------------------------------------------ */
    /* Electrical power                                              */
    /* ------------------------------------------------------------ */

    port def PowerPort {
        doc /*
         * 270 V DC primary electrical supply from the power and thermal
         * management system to a mission load (radar, DAS, mission computer,
         * datalink, crew station, weapons bay). Current and power are the
         * draw carried at this port.
         */
        out attribute voltage : ElectricPotentialValue default 270 [V];
        out attribute current : ElectricCurrentValue default 0 [A];
        out attribute power : PowerValue default 0 [W];
    }

    interface def PowerLink {
        doc /* A 270 V DC distribution feeder from the supply bus to one consumer. */
        end supplier : PowerPort;
        end consumer : ~PowerPort;
    }

    /* ------------------------------------------------------------ */
    /* Shaft extracted generator power                               */
    /* ------------------------------------------------------------ */

    port def GeneratorPort {
        doc /*
         * Electrical output of the engine driven generator on one adaptive
         * cycle engine accessory gearbox, about 500 kW each. Power is what
         * the generator delivers to the power and thermal management system.
         */
        out attribute generatorRating : PowerValue default 500 [kW];
        out attribute power : PowerValue default 0 [W];
        out attribute voltage : ElectricPotentialValue default 270 [V];
        out attribute shaftSpeedRpm : Real default 12000.0;
    }

    interface def ShaftPowerLink {
        doc /* Engine generator output into the power and thermal management system. */
        end generator : GeneratorPort;
        end consumer : ~GeneratorPort;
    }

    /* ------------------------------------------------------------ */
    /* Liquid cooling                                                */
    /* ------------------------------------------------------------ */

    port def CoolantPort {
        doc /*
         * PAO liquid cooling supply. The supplier states flow and supply
         * temperature; the load returns the heat it rejects into the loop.
         * The fuel system uses the same port as the loop's fuel heat sink.
         */
        out attribute flowRate : VolumeFlowRateValue default 0.002 [m^3/s];
        out attribute supplyTemperatureC : Real default 20.0;
        in attribute heatLoad : PowerValue default 0 [W];
    }

    interface def CoolantLoop {
        doc /* One branch of the PAO loop from the thermal management system to a cooled load or heat sink. */
        end supply : CoolantPort;
        end consumer : ~CoolantPort;
    }

    /* ------------------------------------------------------------ */
    /* Fuel                                                          */
    /* ------------------------------------------------------------ */

    port def FuelPort {
        doc /*
         * Engine fuel feed: mass flow in kg/s and boost pump delivery
         * pressure. Maximum afterburning flow of a large adaptive engine is
         * a few kg/s.
         */
        out attribute fuelFlowKgS : Real default 1.2;
        out attribute maxFuelFlowKgS : Real default 5.0;
        out attribute pressure : PressureValue default 350000 [Pa];
    }

    interface def FuelLine {
        doc /* Boost pump feed from the fuel system to one engine. */
        end tank : FuelPort;
        end feed : ~FuelPort;
    }

    /* ------------------------------------------------------------ */
    /* Mission data                                                  */
    /* ------------------------------------------------------------ */

    port def MissionDataPort {
        doc /*
         * Fibre optic mission bus endpoint. Data rate is the stream this
         * endpoint sends, link capacity the optical link it sits on, and hop
         * latency the switching delay added on the way to the mission
         * computer. Rates in Mbit/s.
         */
        out attribute dataRateMbps : Real default 100.0;
        attribute linkCapacityMbps : Real default 10000.0;
        attribute hopLatency : DurationValue default 0.0002 [s];
    }

    interface def MissionBus {
        doc /* A fibre mission data link from a sensor or the mission computer to its consumer. */
        end source : MissionDataPort;
        end sink : ~MissionDataPort;
    }

    /* ------------------------------------------------------------ */
    /* Weapon stations                                               */
    /* ------------------------------------------------------------ */

    port def WeaponStationPort {
        doc /*
         * Store management interface between the mission computer and the
         * internal weapons bay: release commands go out, station status
         * comes back. Release latency is the time from the release command
         * to the store ejector firing, doors included when they are open.
         */
        out attribute releaseLatency : DurationValue default 0.02 [s];
        out attribute stationCount : Integer default 6;
        in attribute storeStatus : StoreStatus default StoreStatus::loaded;
        in attribute storesReady : Integer default 6;
    }

    interface def WeaponStationLink {
        doc /* Release command and store status between the mission computer and the weapons bay. */
        end controller : WeaponStationPort;
        end bay : ~WeaponStationPort;
    }

    /* ------------------------------------------------------------ */
    /* Engine mount                                                  */
    /* ------------------------------------------------------------ */

    port def EngineMountPort {
        doc /* Engine thrust mount seat in the airframe: carries thrust, weight and gyroscopic loads. */
        in attribute thrustLoad : ForceValue default 0 [N];
        attribute cycleMode : CycleMode default CycleMode::highBypass;
    }

    interface def EngineMount {
        doc /*
         * Each buried engine is held by forward trunnion and aft link mounts
         * on the body bulkheads, taken together as one fixed joint. The
         * capacities are the mount's rated force, three times the 200 kN
         * maximum wet thrust, and its rated bending moment.
         */
        @Joint {
            kind = JointKind::fixed;
            axisX = 1.0;
            capacityN = 600000.0;
            momentCapacityNm = 400000.0;
        }
        end airframe : EngineMountPort;
        end engine : ~EngineMountPort;
    }

    /* ------------------------------------------------------------ */
    /* Flight control actuation                                      */
    /* ------------------------------------------------------------ */

    port def ActuatorPort {
        doc /* Elevon command from the flight control computer: commanded deflection and rate out, hinge moment back. */
        out attribute commandDeg : Real default 0.0;
        out attribute rateLimitDegS : Real default 80.0;
        in attribute hingeMomentNm : Real default 0.0;
    }

    interface def ActuatorLink {
        doc /* Fly by wire command lane from the flight control computer to one elevon actuator. */
        end command : ActuatorPort;
        end drive : ~ActuatorPort;
    }
}

package SixthGenFighterParts {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import ShapeItems::*;
    private import MBEstudio::*;
    private import SixthGenFighterInterfaces::*;

    /* ------------------------------------------------------------ */
    /* Flight control surfaces                                       */
    /* ------------------------------------------------------------ */

    part def Elevon {
        doc /*
         * One trailing edge elevon on an electro hydrostatic actuator. Pitch
         * and roll come from the four elevons together, so a tailless
         * aircraft needs no fins. The surface is a wedge from the hinge line
         * to the trailing edge, run along the hinge.
         */
        @Material { name = "carbon composite surface with radar absorbent edge"; finish = Finish::paint; color = "#555b63"; roughness = 0.7; }
        attribute mass :> ISQ::mass default 85 [kg];
        attribute chord : LengthValue default 0.9 [m];
        attribute hingeLength : LengthValue default 2.6 [m];
        attribute hingeThickness : LengthValue default 0.07 [m];
        attribute maxDeflectionDeg : Real default 30.0;
        attribute rateDegS : Real default 80.0;
        port drive : ~ActuatorPort;
        item envelope : RectangularCuboid {
            @Envelope { source = EnvelopeSource::computed; rule = "chord by hinge length by hinge thickness"; }
            :>> length = chord;
            :>> width = hingeLength;
            :>> height = hingeThickness;
        }
        item surface : Extrude {
            doc /* Wedge section, hinge forward and trailing edge aft, swept along the hinge line. */
            :>> yawDeg = 90.0;
            :>> y = -hingeLength / 2;
            :>> distance = hingeLength;
            item wedge : Outline {
                item hingeTop : OutlinePoint { :>> u = -chord / 2; :>> v = hingeThickness / 2; }
                item trailingEdge : OutlinePoint { :>> u = chord / 2; :>> v = 0 [m]; }
                item hingeBottom : OutlinePoint { :>> u = -chord / 2; :>> v = -hingeThickness / 2; }
            }
        }
        item hingeFairing : Rod {
            doc /* Rounded hinge nose that turns inside the wing cove. */
            :>> yawDeg = 90.0;
            :>> x = -chord / 2;
            :>> radius = hingeThickness / 2;
            :>> length = hingeLength;
        }
        @Safety { asil = Asil::D; isolationGroup = "flightControl"; }
    }

    /* ------------------------------------------------------------ */
    /* Airframe                                                      */
    /* ------------------------------------------------------------ */

    part def BlendedWingBody {
        doc /*
         * Tailless lambda planform composite airframe. A faceted, chined
         * centre body holds the two buried engines, the internal weapons bay,
         * the fuel and the mission systems; a thin cranked wing blends into
         * it, and four elevons on the trailing edge give pitch and roll. The
         * envelope is a hollow shell around the internal systems. Wing area
         * is a continuous trade variable: it sets the wing root chord, and
         * every wing chord is a share of it, so the trade moves the leading
         * edge in the planform loft.
         */
        @Material { name = "carbon composite skin with radar absorbent coating"; finish = Finish::paint; color = "#5d636b"; roughness = 0.7; }
        @Support { note = "free flight: the load cases are reacted at the airframe, which carries every bay, mount and gear leg"; }
        attribute bodyLength : LengthValue default 22.0 [m];
        attribute span : LengthValue default 16.0 [m];
        attribute bodyWidth : LengthValue default 4.6 [m];
        attribute bodyHeight : LengthValue default 2.6 [m];
        attribute wingArea : AreaValue default 100 [m * m] {
            doc /* Reference wing area; a continuous trade variable from 80 to 120 square metres. */
            @DesignVariable { lower = 80.0; upper = 120.0; steps = 9; }
        }
        attribute rootChord : LengthValue = 2 * wingArea / span;
        attribute meanChord : LengthValue = wingArea / span;
        attribute leadingEdgeSweepDeg : Real default 50.0;
        attribute liftToDrag : Real default 10.0;
        attribute structureMass : MassValue default 9160 [kg];
        attribute mass :> ISQ::mass = structureMass + leftInboardElevon.mass + rightInboardElevon.mass
            + leftOuterElevon.mass + rightOuterElevon.mass;
        port engineMount : EngineMountPort[2];
        item envelope : RectangularCuboid {
            @Envelope { source = EnvelopeSource::computed; hollow = true; wallThicknessM = 0.01; rule = "body length by wing span by centre body height"; }
            :>> length = bodyLength;
            :>> width = span;
            :>> height = bodyHeight;
        }
        item centreBody : Loft {
            doc /* Faceted blended body, tail to nose: flat top, shoulder facets, a sharp chine all round, flat bottom. Stations scale with the body length, width and height. */
            item tail : Outline {
                :>> station = bodyLength * -0.4818;
                item topLeft : OutlinePoint { :>> u = bodyWidth * 0.25; :>> v = bodyHeight * 0.0923; }
                item shoulderLeft : OutlinePoint { :>> u = bodyWidth * 0.337; :>> v = bodyHeight * 0.0615; }
                item chineLeft : OutlinePoint { :>> u = bodyWidth * 0.3696; :>> v = bodyHeight * 0.0154; }
                item bottomLeft : OutlinePoint { :>> u = bodyWidth * 0.2826; :>> v = bodyHeight * -0.0615; }
                item bottomRight : OutlinePoint { :>> u = bodyWidth * -0.2826; :>> v = bodyHeight * -0.0615; }
                item chineRight : OutlinePoint { :>> u = bodyWidth * -0.3696; :>> v = bodyHeight * 0.0154; }
                item shoulderRight : OutlinePoint { :>> u = bodyWidth * -0.337; :>> v = bodyHeight * 0.0615; }
                item topRight : OutlinePoint { :>> u = bodyWidth * -0.25; :>> v = bodyHeight * 0.0923; }
            }
            item nozzleDeck : Outline {
                :>> station = bodyLength * -0.4364;
                item topLeft : OutlinePoint { :>> u = bodyWidth * 0.2283; :>> v = bodyHeight * 0.2115; }
                item shoulderLeft : OutlinePoint { :>> u = bodyWidth * 0.3804; :>> v = bodyHeight * 0.1462; }
                item chineLeft : OutlinePoint { :>> u = bodyWidth * 0.4239; :>> v = 0 [m]; }
                item bottomLeft : OutlinePoint { :>> u = bodyWidth * 0.337; :>> v = bodyHeight * -0.1846; }
                item bottomRight : OutlinePoint { :>> u = bodyWidth * -0.337; :>> v = bodyHeight * -0.1846; }
                item chineRight : OutlinePoint { :>> u = bodyWidth * -0.4239; :>> v = 0 [m]; }
                item shoulderRight : OutlinePoint { :>> u = bodyWidth * -0.3804; :>> v = bodyHeight * 0.1462; }
                item topRight : OutlinePoint { :>> u = bodyWidth * -0.2283; :>> v = bodyHeight * 0.2115; }
            }
            item engineBay : Outline {
                :>> station = bodyLength * -0.2955;
                item topLeft : OutlinePoint { :>> u = bodyWidth * 0.2065; :>> v = bodyHeight * 0.3538; }
                item shoulderLeft : OutlinePoint { :>> u = bodyWidth * 0.4239; :>> v = bodyHeight * 0.2385; }
                item chineLeft : OutlinePoint { :>> u = bodyWidth * 0.4891; :>> v = bodyHeight * -0.0192; }
                item bottomLeft : OutlinePoint { :>> u = bodyWidth * 0.3804; :>> v = bodyHeight * -0.3308; }
                item bottomRight : OutlinePoint { :>> u = bodyWidth * -0.3804; :>> v = bodyHeight * -0.3308; }
                item chineRight : OutlinePoint { :>> u = bodyWidth * -0.4891; :>> v = bodyHeight * -0.0192; }
                item shoulderRight : OutlinePoint { :>> u = bodyWidth * -0.4239; :>> v = bodyHeight * 0.2385; }
                item topRight : OutlinePoint { :>> u = bodyWidth * -0.2065; :>> v = bodyHeight * 0.3538; }
            }
            item wingBox : Outline {
                :>> station = bodyLength * -0.1136;
                item topLeft : OutlinePoint { :>> u = bodyWidth * 0.1848; :>> v = bodyHeight * 0.4; }
                item shoulderLeft : OutlinePoint { :>> u = bodyWidth * 0.4022; :>> v = bodyHeight * 0.2538; }
                item chineLeft : OutlinePoint { :>> u = bodyWidth * 0.5; :>> v = bodyHeight * -0.0385; }
                item bottomLeft : OutlinePoint { :>> u = bodyWidth * 0.3696; :>> v = bodyHeight * -0.3769; }
                item bottomRight : OutlinePoint { :>> u = bodyWidth * -0.3696; :>> v = bodyHeight * -0.3769; }
                item chineRight : OutlinePoint { :>> u = bodyWidth * -0.5; :>> v = bodyHeight * -0.0385; }
                item shoulderRight : OutlinePoint { :>> u = bodyWidth * -0.4022; :>> v = bodyHeight * 0.2538; }
                item topRight : OutlinePoint { :>> u = bodyWidth * -0.1848; :>> v = bodyHeight * 0.4; }
            }
            item weaponsBay : Outline {
                :>> station = bodyLength * 0.0455;
                item topLeft : OutlinePoint { :>> u = bodyWidth * 0.1565; :>> v = bodyHeight * 0.4; }
                item shoulderLeft : OutlinePoint { :>> u = bodyWidth * 0.3587; :>> v = bodyHeight * 0.2385; }
                item chineLeft : OutlinePoint { :>> u = bodyWidth * 0.5; :>> v = bodyHeight * -0.0538; }
                item bottomLeft : OutlinePoint { :>> u = bodyWidth * 0.337; :>> v = bodyHeight * -0.3923; }
                item bottomRight : OutlinePoint { :>> u = bodyWidth * -0.337; :>> v = bodyHeight * -0.3923; }
                item chineRight : OutlinePoint { :>> u = bodyWidth * -0.5; :>> v = bodyHeight * -0.0538; }
                item shoulderRight : OutlinePoint { :>> u = bodyWidth * -0.3587; :>> v = bodyHeight * 0.2385; }
                item topRight : OutlinePoint { :>> u = bodyWidth * -0.1565; :>> v = bodyHeight * 0.4; }
            }
            item intakeLip : Outline {
                :>> station = bodyLength * 0.2091;
                item topLeft : OutlinePoint { :>> u = bodyWidth * 0.1087; :>> v = bodyHeight * 0.3538; }
                item shoulderLeft : OutlinePoint { :>> u = bodyWidth * 0.2717; :>> v = bodyHeight * 0.2154; }
                item chineLeft : OutlinePoint { :>> u = bodyWidth * 0.4022; :>> v = bodyHeight * -0.0692; }
                item bottomLeft : OutlinePoint { :>> u = bodyWidth * 0.2391; :>> v = bodyHeight * -0.3692; }
                item bottomRight : OutlinePoint { :>> u = bodyWidth * -0.2391; :>> v = bodyHeight * -0.3692; }
                item chineRight : OutlinePoint { :>> u = bodyWidth * -0.4022; :>> v = bodyHeight * -0.0692; }
                item shoulderRight : OutlinePoint { :>> u = bodyWidth * -0.2717; :>> v = bodyHeight * 0.2154; }
                item topRight : OutlinePoint { :>> u = bodyWidth * -0.1087; :>> v = bodyHeight * 0.3538; }
            }
            item cockpit : Outline {
                :>> station = bodyLength * 0.3182;
                item topLeft : OutlinePoint { :>> u = bodyWidth * 0.0696; :>> v = bodyHeight * 0.2846; }
                item shoulderLeft : OutlinePoint { :>> u = bodyWidth * 0.1783; :>> v = bodyHeight * 0.1769; }
                item chineLeft : OutlinePoint { :>> u = bodyWidth * 0.2717; :>> v = bodyHeight * -0.0846; }
                item bottomLeft : OutlinePoint { :>> u = bodyWidth * 0.1435; :>> v = bodyHeight * -0.3154; }
                item bottomRight : OutlinePoint { :>> u = bodyWidth * -0.1435; :>> v = bodyHeight * -0.3154; }
                item chineRight : OutlinePoint { :>> u = bodyWidth * -0.2717; :>> v = bodyHeight * -0.0846; }
                item shoulderRight : OutlinePoint { :>> u = bodyWidth * -0.1783; :>> v = bodyHeight * 0.1769; }
                item topRight : OutlinePoint { :>> u = bodyWidth * -0.0696; :>> v = bodyHeight * 0.2846; }
            }
            item radarBay : Outline {
                :>> station = bodyLength * 0.4;
                item topLeft : OutlinePoint { :>> u = bodyWidth * 0.0478; :>> v = bodyHeight * 0.2154; }
                item shoulderLeft : OutlinePoint { :>> u = bodyWidth * 0.1217; :>> v = bodyHeight * 0.1385; }
                item chineLeft : OutlinePoint { :>> u = bodyWidth * 0.1957; :>> v = bodyHeight * -0.0692; }
                item bottomLeft : OutlinePoint { :>> u = bodyWidth * 0.1; :>> v = bodyHeight * -0.2462; }
                item bottomRight : OutlinePoint { :>> u = bodyWidth * -0.1; :>> v = bodyHeight * -0.2462; }
                item chineRight : OutlinePoint { :>> u = bodyWidth * -0.1957; :>> v = bodyHeight * -0.0692; }
                item shoulderRight : OutlinePoint { :>> u = bodyWidth * -0.1217; :>> v = bodyHeight * 0.1385; }
                item topRight : OutlinePoint { :>> u = bodyWidth * -0.0478; :>> v = bodyHeight * 0.2154; }
            }
            item radome : Outline {
                :>> station = bodyLength * 0.4591;
                item topLeft : OutlinePoint { :>> u = bodyWidth * 0.0217; :>> v = bodyHeight * 0.1154; }
                item shoulderLeft : OutlinePoint { :>> u = bodyWidth * 0.0652; :>> v = bodyHeight * 0.0692; }
                item chineLeft : OutlinePoint { :>> u = bodyWidth * 0.1087; :>> v = bodyHeight * -0.0462; }
                item bottomLeft : OutlinePoint { :>> u = bodyWidth * 0.0522; :>> v = bodyHeight * -0.1462; }
                item bottomRight : OutlinePoint { :>> u = bodyWidth * -0.0522; :>> v = bodyHeight * -0.1462; }
                item chineRight : OutlinePoint { :>> u = bodyWidth * -0.1087; :>> v = bodyHeight * -0.0462; }
                item shoulderRight : OutlinePoint { :>> u = bodyWidth * -0.0652; :>> v = bodyHeight * 0.0692; }
                item topRight : OutlinePoint { :>> u = bodyWidth * -0.0217; :>> v = bodyHeight * 0.1154; }
            }
            item noseTip : Outline {
                :>> station = bodyLength * 0.5;
                item topLeft : OutlinePoint { :>> u = bodyWidth * 0.0022; :>> v = 0 [m]; }
                item shoulderLeft : OutlinePoint { :>> u = bodyWidth * 0.0065; :>> v = bodyHeight * -0.0077; }
                item chineLeft : OutlinePoint { :>> u = bodyWidth * 0.013; :>> v = bodyHeight * -0.0231; }
                item bottomLeft : OutlinePoint { :>> u = bodyWidth * 0.0043; :>> v = bodyHeight * -0.0385; }
                item bottomRight : OutlinePoint { :>> u = bodyWidth * -0.0043; :>> v = bodyHeight * -0.0385; }
                item chineRight : OutlinePoint { :>> u = bodyWidth * -0.013; :>> v = bodyHeight * -0.0231; }
                item shoulderRight : OutlinePoint { :>> u = bodyWidth * -0.0065; :>> v = bodyHeight * -0.0077; }
                item topRight : OutlinePoint { :>> u = bodyWidth * -0.0022; :>> v = 0 [m]; }
            }
        }
        item wing : Loft {
            doc /*
             * Cranked lambda wing, built along the span and mirrored: 50 degree
             * leading edge sweep, the inboard trailing edge swept forward to the
             * crank, the outboard one swept back to the tip. Every chord is a
             * share of the root chord, so the wing area trade moves the leading
             * edge and the thickness with it. Airfoil u runs aft.
             */
            :>> yawDeg = 90.0;
            :>> mirror = MirrorPlane::xz;
            item root : Outline {
                :>> station = span * 0.0625;
                item leadingEdge : OutlinePoint { :>> u = bodyLength * 0.4886 - rootChord * 0.98; :>> v = bodyHeight * -0.0462; }
                item upperFront : OutlinePoint { :>> u = bodyLength * 0.4886 - rootChord * 0.735; :>> v = bodyHeight * -0.0462 + rootChord * 0.0294; }
                item upperAft : OutlinePoint { :>> u = bodyLength * 0.4886 - rootChord * 0.3724; :>> v = bodyHeight * -0.0462 + rootChord * 0.0247; }
                item trailingEdge : OutlinePoint { :>> u = bodyLength * 0.4886; :>> v = bodyHeight * -0.0462; }
                item lowerAft : OutlinePoint { :>> u = bodyLength * 0.4886 - rootChord * 0.3724; :>> v = bodyHeight * -0.0462 - rootChord * 0.0176; }
                item lowerFront : OutlinePoint { :>> u = bodyLength * 0.4886 - rootChord * 0.735; :>> v = bodyHeight * -0.0462 - rootChord * 0.0235; }
            }
            item bodySide : Outline {
                :>> station = span * 0.15;
                item leadingEdge : OutlinePoint { :>> u = bodyLength * 0.4614 - rootChord * 0.7987; :>> v = bodyHeight * -0.0385; }
                item upperFront : OutlinePoint { :>> u = bodyLength * 0.4614 - rootChord * 0.599; :>> v = bodyHeight * -0.0385 + rootChord * 0.022; }
                item upperAft : OutlinePoint { :>> u = bodyLength * 0.4614 - rootChord * 0.3035; :>> v = bodyHeight * -0.0385 + rootChord * 0.0185; }
                item trailingEdge : OutlinePoint { :>> u = bodyLength * 0.4614; :>> v = bodyHeight * -0.0385; }
                item lowerAft : OutlinePoint { :>> u = bodyLength * 0.4614 - rootChord * 0.3035; :>> v = bodyHeight * -0.0385 - rootChord * 0.0132; }
                item lowerFront : OutlinePoint { :>> u = bodyLength * 0.4614 - rootChord * 0.599; :>> v = bodyHeight * -0.0385 - rootChord * 0.0176; }
            }
            item crank : Outline {
                :>> station = span * 0.3;
                item leadingEdge : OutlinePoint { :>> u = bodyLength * 0.3432 - rootChord * 0.3622; :>> v = bodyHeight * -0.0231; }
                item upperFront : OutlinePoint { :>> u = bodyLength * 0.3432 - rootChord * 0.2717; :>> v = bodyHeight * -0.0231 + rootChord * 0.0082; }
                item upperAft : OutlinePoint { :>> u = bodyLength * 0.3432 - rootChord * 0.1377; :>> v = bodyHeight * -0.0231 + rootChord * 0.0068; }
                item trailingEdge : OutlinePoint { :>> u = bodyLength * 0.3432; :>> v = bodyHeight * -0.0231; }
                item lowerAft : OutlinePoint { :>> u = bodyLength * 0.3432 - rootChord * 0.1377; :>> v = bodyHeight * -0.0231 - rootChord * 0.0049; }
                item lowerFront : OutlinePoint { :>> u = bodyLength * 0.3432 - rootChord * 0.2717; :>> v = bodyHeight * -0.0231 - rootChord * 0.0065; }
            }
            item tip : Outline {
                :>> station = span * 0.5;
                item leadingEdge : OutlinePoint { :>> u = bodyLength * 0.3795 - rootChord * 0.1216; :>> v = 0 [m]; }
                item upperFront : OutlinePoint { :>> u = bodyLength * 0.3795 - rootChord * 0.0912; :>> v = rootChord * 0.0021; }
                item upperAft : OutlinePoint { :>> u = bodyLength * 0.3795 - rootChord * 0.0462; :>> v = rootChord * 0.0018; }
                item trailingEdge : OutlinePoint { :>> u = bodyLength * 0.3795; :>> v = 0 [m]; }
                item lowerAft : OutlinePoint { :>> u = bodyLength * 0.3795 - rootChord * 0.0462; :>> v = -rootChord * 0.0013; }
                item lowerFront : OutlinePoint { :>> u = bodyLength * 0.3795 - rootChord * 0.0912; :>> v = -rootChord * 0.0017; }
            }
        }
        item intakes : Loft {
            doc /* Caret intake fairings under the chines, one each side, from the swept lip back into the body. */
            :>> mirror = MirrorPlane::xz;
            item lip : Outline {
                :>> station = 4.9 [m];
                item innerTop : OutlinePoint { :>> u = 1.22 [m]; :>> v = -0.28 [m]; }
                item outerTop : OutlinePoint { :>> u = 2.02 [m]; :>> v = -0.3 [m]; }
                item outerBottom : OutlinePoint { :>> u = 1.84 [m]; :>> v = -0.93 [m]; }
                item innerBottom : OutlinePoint { :>> u = 1.12 [m]; :>> v = -0.93 [m]; }
            }
            item throat : Outline {
                :>> station = 3.2 [m];
                item innerTop : OutlinePoint { :>> u = 1.3 [m]; :>> v = -0.31 [m]; }
                item outerTop : OutlinePoint { :>> u = 2.12 [m]; :>> v = -0.3 [m]; }
                item outerBottom : OutlinePoint { :>> u = 1.94 [m]; :>> v = -0.95 [m]; }
                item innerBottom : OutlinePoint { :>> u = 1.25 [m]; :>> v = -0.96 [m]; }
            }
            item blend : Outline {
                :>> station = 1.2 [m];
                item innerTop : OutlinePoint { :>> u = 1.45 [m]; :>> v = -0.45 [m]; }
                item outerTop : OutlinePoint { :>> u = 2.05 [m]; :>> v = -0.35 [m]; }
                item outerBottom : OutlinePoint { :>> u = 1.85 [m]; :>> v = -0.9 [m]; }
                item innerBottom : OutlinePoint { :>> u = 1.4 [m]; :>> v = -0.95 [m]; }
            }
        }
        item intakeMouths : Loft {
            doc /* The open intake mouths, cut a metre into the fairings toward the serpentine ducts. */
            :>> combine = Combine::subtract;
            :>> mirror = MirrorPlane::xz;
            item face : Outline {
                :>> station = 5.0 [m];
                item innerTop : OutlinePoint { :>> u = 1.3 [m]; :>> v = -0.36 [m]; }
                item outerTop : OutlinePoint { :>> u = 1.93 [m]; :>> v = -0.37 [m]; }
                item outerBottom : OutlinePoint { :>> u = 1.78 [m]; :>> v = -0.86 [m]; }
                item innerBottom : OutlinePoint { :>> u = 1.2 [m]; :>> v = -0.86 [m]; }
            }
            item duct : Outline {
                :>> station = 3.9 [m];
                item innerTop : OutlinePoint { :>> u = 1.36 [m]; :>> v = -0.4 [m]; }
                item outerTop : OutlinePoint { :>> u = 1.9 [m]; :>> v = -0.4 [m]; }
                item outerBottom : OutlinePoint { :>> u = 1.78 [m]; :>> v = -0.84 [m]; }
                item innerBottom : OutlinePoint { :>> u = 1.3 [m]; :>> v = -0.84 [m]; }
            }
        }
        item exhaustTroughs : Block {
            doc /* Shallow shielded troughs in the upper beavertail aft of the 2D nozzles. */
            :>> combine = Combine::subtract;
            :>> x = -10.75 [m];
            :>> y = 1.25 [m];
            :>> z = 0.24 [m];
            :>> length = 0.5 [m];
            :>> width = 1.05 [m];
            :>> height = 0.2 [m];
            :>> mirror = MirrorPlane::xz;
        }
        part leftInboardElevon : Elevon {
            :>> hingeLength = 2.65 [m];
            :>> hingeThickness = 0.1 [m];
            @Placement { mode = LayoutMode::fixed; xM = -8.545; yM = 3.27; zM = -0.08; yawDeg = -47.3; }
        }
        part rightInboardElevon : Elevon {
            :>> hingeLength = 2.65 [m];
            :>> hingeThickness = 0.1 [m];
            @Placement { mode = LayoutMode::fixed; xM = -8.545; yM = -3.27; zM = -0.08; yawDeg = 47.3; }
        }
        part leftOuterElevon : Elevon {
            :>> hingeLength = 2.68 [m];
            @Placement { mode = LayoutMode::fixed; xM = -7.489; yM = 6.409; zM = -0.03; yawDeg = 14.04; }
        }
        part rightOuterElevon : Elevon {
            :>> hingeLength = 2.68 [m];
            @Placement { mode = LayoutMode::fixed; xM = -7.489; yM = -6.409; zM = -0.03; yawDeg = -14.04; }
        }
        @Placement { anchor = Anchor::origin; }
        @Safety { asil = Asil::D; }
    }

    /* ------------------------------------------------------------ */
    /* Propulsion                                                    */
    /* ------------------------------------------------------------ */

    part def AdaptiveCycleEngine {
        doc /*
         * Three stream adaptive cycle turbofan buried in the centre body. The
         * third stream opens for range (high bypass) and closes for thrust.
         * The accessory gearbox drives a 500 kW generator onto the 270 V DC
         * bus. Thrust, mass, cruise TSFC and third stream bypass are defaults
         * the engine variants override. The body runs from a 2D vectoring
         * nozzle through the augmentor and core to the fan case and inlet
         * face, with the gearbox and generator slung under the fan case.
         */
        @Material { name = "titanium and nickel alloy casing"; finish = Finish::metal; color = "#6f6a63"; roughness = 0.45; }
        attribute maxThrust : ForceValue default 200000 [N];
        attribute mass :> ISQ::mass default 3700 [kg];
        attribute tsfcPerHour : Real default 0.62;
        attribute thirdStreamBypass : Real default 0.6;
        attribute fanDiameter : LengthValue default 1.2 [m];
        attribute engineLength : LengthValue default 5.8 [m];
        attribute fanBladeCount : Integer default 18;
        attribute generatorRating : PowerValue default 500 [kW];
        attribute cycleMode : CycleMode default CycleMode::highBypass;
        port mount : ~EngineMountPort { out :>> thrustLoad = maxThrust; }
        port fuelIn : ~FuelPort;
        port genOut : GeneratorPort;
        item envelope : RightCircularCylinder {
            @Envelope { source = EnvelopeSource::computed; rule = "radius from fan diameter, length is the engine length"; }
            :>> radius = fanDiameter * 0.55;
            :>> height = engineLength;
        }
        item casing : Loft {
            doc /* Engine case from the flattened 2D nozzle exit to the inlet face, stations along the envelope axis. */
            :>> pitchDeg = -90.0;
            item nozzleExit : Section { :>> station = -engineLength / 2; :>> width = fanDiameter * 0.85; :>> height = fanDiameter * 0.34; :>> exponent = 5.0; }
            item nozzleThroat : Section { :>> station = -engineLength * 0.4; :>> width = fanDiameter * 0.82; :>> height = fanDiameter * 0.5; :>> exponent = 4.0; }
            item augmentor : Section { :>> station = -engineLength * 0.22; :>> width = fanDiameter * 0.92; :>> height = fanDiameter * 0.92; }
            item core : Section { :>> station = engineLength * 0.08; :>> width = fanDiameter * 0.9; :>> height = fanDiameter * 0.9; }
            item fanCase : Section { :>> station = engineLength * 0.33; :>> width = fanDiameter * 1.1; :>> height = fanDiameter * 1.1; }
            item inletFace : Section { :>> station = engineLength / 2; :>> width = fanDiameter * 1.05; :>> height = fanDiameter * 1.05; }
        }
        item nozzleExhaust : Block {
            doc /* The open nozzle exit. */
            :>> combine = Combine::subtract;
            :>> z = -engineLength / 2;
            :>> length = fanDiameter * 0.72;
            :>> width = fanDiameter * 0.24;
            :>> height = 0.5 [m];
        }
        item fanFace : Rod {
            doc /* The recessed fan face behind the inlet lip. */
            :>> combine = Combine::subtract;
            :>> pitchDeg = -90.0;
            :>> z = engineLength / 2;
            :>> radius = fanDiameter * 0.48;
            :>> length = 0.3 [m];
        }
        item spinner : Loft {
            :>> pitchDeg = -90.0;
            item hub : Section { :>> station = engineLength / 2 - 0.2 [m]; :>> width = fanDiameter * 0.32; :>> height = fanDiameter * 0.32; }
            item tip : Section { :>> station = engineLength / 2 - 0.02 [m]; :>> width = 0.03 [m]; :>> height = 0.03 [m]; }
        }
        item fanBlades : Block {
            doc /* First stage fan blades, radial from the hub to the case. */
            :>> x = fanDiameter * 0.3;
            :>> z = engineLength / 2 - 0.16 [m];
            :>> rollDeg = 30.0;
            :>> length = fanDiameter * 0.36;
            :>> width = 0.11 [m];
            :>> height = 0.02 [m];
            :>> count = fanBladeCount;
            :>> turnDeg = 20.0;
            :>> turnAxis = Axis::z;
        }
        item gearbox : Block {
            doc /* Accessory gearbox under the fan case. */
            :>> x = fanDiameter * 0.56;
            :>> z = engineLength * 0.2;
            :>> length = 0.24 [m];
            :>> width = 0.5 [m];
            :>> height = 0.9 [m];
        }
        item generator : Rod {
            doc /* The 500 kW engine driven generator on the gearbox pad. */
            :>> pitchDeg = -90.0;
            :>> x = fanDiameter * 0.5;
            :>> y = 0.32 [m];
            :>> z = engineLength * 0.05;
            :>> radius = 0.16 [m];
            :>> length = 0.6 [m];
        }
        @Placement { pitchDeg = 90.0; near = "airframe"; }
        @Budget { powerW = -500000.0; bus = "dc270"; }
        @Safety { asil = Asil::D; isolationGroup = "propulsion"; }

        state cycleModes {
            doc /* A state usage, so its assignments read the engine's own cycle mode. */
            entry; then rangeCycle;
            state rangeCycle { entry assign cycleMode := CycleMode::highBypass; }
            state thrustCycle { entry assign cycleMode := CycleMode::highThrust; }
            transition engageCombat first rangeCycle then thrustCycle;
            transition resumeCruise first thrustCycle then rangeCycle;
        }
    }

    /* ------------------------------------------------------------ */
    /* Weapons                                                       */
    /* ------------------------------------------------------------ */

    part def LongRangeMissile {
        doc /*
         * Long range air to air missile carried internally on an ejector
         * launcher: ogive radome over the seeker, motor body with long chord
         * strakes, and cruciform tail control fins set at 45 degrees so the
         * stores pack side by side.
         */
        @Material { name = "painted steel and composite airframe"; finish = Finish::paint; color = "#c8ccd0"; roughness = 0.5; }
        attribute mass :> ISQ::mass default 160 [kg];
        attribute bodyDiameter : LengthValue default 0.178 [m];
        attribute storeLength : LengthValue default 3.66 [m];
        attribute finSpan : LengthValue default 0.45 [m];
        attribute rangeKm : Real default 160.0;
        item envelope : RightCircularCylinder {
            @Envelope { source = EnvelopeSource::computed; rule = "radius is half the fin span, height is the store length"; }
            :>> radius = finSpan / 2;
            :>> height = storeLength;
        }
        item motorBody : Rod {
            doc /* Motor and guidance body along the envelope axis. */
            :>> pitchDeg = -90.0;
            :>> z = -storeLength * 0.06;
            :>> radius = bodyDiameter / 2;
            :>> length = storeLength * 0.88;
        }
        item noseCone : Loft {
            doc /* Tangent ogive radome. */
            :>> pitchDeg = -90.0;
            item coneBase : Section { :>> station = storeLength * 0.38; :>> width = bodyDiameter; :>> height = bodyDiameter; }
            item shoulder : Section { :>> station = storeLength * 0.43; :>> width = bodyDiameter * 0.82; :>> height = bodyDiameter * 0.82; }
            item ogive : Section { :>> station = storeLength * 0.47; :>> width = bodyDiameter * 0.5; :>> height = bodyDiameter * 0.5; }
            item coneTip : Section { :>> station = storeLength / 2; :>> width = 0.02 [m]; :>> height = 0.02 [m]; }
        }
        item strakes : Block {
            doc /* Long chord, low span mid body strakes. */
            :>> yawDeg = 45.0;
            :>> z = -storeLength * 0.02;
            :>> length = bodyDiameter + 0.1 [m];
            :>> width = 0.006 [m];
            :>> height = storeLength * 0.42;
            :>> count = 2;
            :>> turnDeg = 90.0;
            :>> turnAxis = Axis::z;
        }
        item fins : Block {
            doc /* Cruciform tail control fins. */
            :>> yawDeg = 45.0;
            :>> z = -storeLength * 0.42;
            :>> length = finSpan;
            :>> width = 0.008 [m];
            :>> height = 0.25 [m];
            :>> count = 2;
            :>> turnDeg = 90.0;
            :>> turnAxis = Axis::z;
        }
        item motorNozzle : Rod {
            :>> combine = Combine::subtract;
            :>> pitchDeg = -90.0;
            :>> z = -storeLength / 2;
            :>> radius = bodyDiameter * 0.3;
            :>> length = 0.1 [m];
        }
        @Placement { pitchDeg = 90.0; }
    }

    part def InternalWeaponsBay {
        doc /*
         * Centreline internal weapons bay with three pairs of ejector
         * stations side by side. The bay is a hollow shell sized from the
         * stores it carries: its length is the store length plus launcher
         * clearance, its width the store count times the side by side store
         * spacing. Two sawtooth edged doors close the bay flush with the
         * lower skin and open before release.
         */
        @Material { name = "composite bay structure with titanium door frames"; finish = Finish::paint; color = "#6a7078"; roughness = 0.6; }
        attribute storeCount : Integer default 6;
        attribute storeSpacing : LengthValue default 0.42 [m];
        attribute bayDepth : LengthValue default 0.9 [m];
        attribute bayLength : LengthValue = innerStations.storeLength + 0.6 [m];
        attribute bayWidth : LengthValue = storeCount * storeSpacing + 0.3 [m];
        attribute storesMass : MassValue = storeCount * innerStations.mass;
        attribute releaseLatency : DurationValue default 0.02 [s];
        attribute doorTravelTime : DurationValue default 0.4 [s];
        attribute doorsOpen : Boolean default false;
        attribute power : PowerValue default 2 [kW];
        attribute mass :> ISQ::mass default 650 [kg];
        part innerStations : LongRangeMissile[2] {
            @Placement { mode = LayoutMode::fixed; xM = 0.0; yM = 0.21; zM = 0.12; pitchDeg = 90.0; }
        }
        part middleStations : LongRangeMissile[2] {
            @Placement { mode = LayoutMode::fixed; xM = 0.0; yM = 0.63; zM = 0.12; pitchDeg = 90.0; }
        }
        part outerStations : LongRangeMissile[2] {
            @Placement { mode = LayoutMode::fixed; xM = 0.0; yM = 1.05; zM = 0.12; pitchDeg = 90.0; }
        }
        port stations : ~WeaponStationPort { out :>> storesReady = storeCount; }
        port powerIn : ~PowerPort { in :>> current = 7.4 [A]; }
        port missionData : ~MissionDataPort;
        item envelope : RectangularCuboid {
            @Envelope { source = EnvelopeSource::computed; hollow = true; wallThicknessM = 0.004; rule = "bay length from store length, width from store count and spacing"; }
            :>> length = bayLength;
            :>> width = bayWidth;
            :>> height = bayDepth;
        }
        item roof : Block {
            :>> z = bayDepth / 2 - 0.01 [m];
            :>> length = bayLength;
            :>> width = bayWidth;
            :>> height = 0.02 [m];
        }
        item sideWalls : Block {
            :>> y = bayWidth / 2 - 0.01 [m];
            :>> length = bayLength;
            :>> width = 0.02 [m];
            :>> height = bayDepth;
            :>> mirror = MirrorPlane::xz;
        }
        item bulkheads : Block {
            :>> x = bayLength / 2 - 0.01 [m];
            :>> length = 0.02 [m];
            :>> width = bayWidth;
            :>> height = bayDepth;
            :>> mirror = MirrorPlane::yz;
        }
        item launchers : Block {
            doc /* Ejector launcher rails, one per station, hung from the roof. */
            :>> y = storeSpacing / 2;
            :>> z = bayDepth / 2 - 0.08 [m];
            :>> length = innerStations.storeLength * 0.7;
            :>> width = 0.07 [m];
            :>> height = 0.12 [m];
            :>> count = 3;
            :>> stepY = storeSpacing;
            :>> mirror = MirrorPlane::xz;
        }
        item doors : Extrude {
            doc /* Bay doors, closed, with sawtooth front and aft edges; the left door is drawn and mirrored. */
            :>> pitchDeg = -90.0;
            :>> z = -bayDepth / 2 - 0.012 [m];
            :>> distance = 0.03 [m];
            :>> mirror = MirrorPlane::xz;
            item panel : Outline {
                item frontInner : OutlinePoint { :>> u = 0.005 [m]; :>> v = -bayLength / 2; }
                item frontTooth1 : OutlinePoint { :>> u = bayWidth * 0.125; :>> v = -bayLength / 2 + 0.22 [m]; }
                item frontNotch1 : OutlinePoint { :>> u = bayWidth * 0.25; :>> v = -bayLength / 2; }
                item frontTooth2 : OutlinePoint { :>> u = bayWidth * 0.375; :>> v = -bayLength / 2 + 0.22 [m]; }
                item frontOuter : OutlinePoint { :>> u = bayWidth / 2; :>> v = -bayLength / 2; }
                item aftOuter : OutlinePoint { :>> u = bayWidth / 2; :>> v = bayLength / 2; }
                item aftTooth2 : OutlinePoint { :>> u = bayWidth * 0.375; :>> v = bayLength / 2 - 0.22 [m]; }
                item aftNotch1 : OutlinePoint { :>> u = bayWidth * 0.25; :>> v = bayLength / 2; }
                item aftTooth1 : OutlinePoint { :>> u = bayWidth * 0.125; :>> v = bayLength / 2 - 0.22 [m]; }
                item aftInner : OutlinePoint { :>> u = 0.005 [m]; :>> v = bayLength / 2; }
            }
        }
        @Placement { mode = LayoutMode::fixed; near = "airframe"; }
        @Budget { powerW = 2000.0; bus = "dc270"; }
        @Safety { asil = Asil::C; isolationGroup = "mission"; }

        state bayDoors {
            doc /* Door sequence: stowed, opening for the door travel time, then deployed for release. */
            entry; then stowed;
            state stowed { entry assign doorsOpen := false; }
            state opening;
            state deployed { entry assign doorsOpen := true; }
            transition commandOpen first stowed then opening;
            transition doorsLocked first opening accept after doorTravelTime then deployed;
            transition commandClose first deployed then stowed;
        }
    }

    /* ------------------------------------------------------------ */
    /* Fuel, power and thermal                                       */
    /* ------------------------------------------------------------ */

    part def FuelSystem {
        doc /*
         * Integral body and wing tanks, boost pumps feeding both engines, and
         * the fuel heat sink of the thermal management loop. The envelope
         * stands for the tank volume: the capacity at JP-8 density over a
         * 7 m by 2.6 m footprint above the weapons bay. The body is the
         * conformal centre tank with a boost pump at each feed.
         */
        @Material { name = "sealed integral tank structure"; finish = Finish::paint; color = "#7a7f86"; roughness = 0.6; }
        attribute capacity : MassValue default 16000 [kg];
        attribute fuelDensityKgM3 : Real = 800.0;
        attribute fuelVolumeM3 : Real = capacity / (1 [kg]) / fuelDensityKgM3;
        attribute tankLength : LengthValue default 7.0 [m];
        attribute tankWidth : LengthValue default 2.6 [m];
        attribute tankHeight : LengthValue = fuelVolumeM3 / (tankLength / (1 [m]) * (tankWidth / (1 [m]))) * (1 [m]);
        attribute heatSinkCapacity : PowerValue default 150 [kW];
        attribute boostPressure : PressureValue default 350000 [Pa];
        attribute power : PowerValue default 30 [kW];
        attribute mass :> ISQ::mass default 900 [kg];
        port feedLeft : FuelPort;
        port feedRight : FuelPort;
        port heatSink : ~CoolantPort;
        port powerIn : ~PowerPort { in :>> current = 111 [A]; }
        item envelope : RectangularCuboid {
            @Envelope { source = EnvelopeSource::computed; rule = "fuel volume at JP-8 density over a 7 m by 2.6 m tank footprint"; }
            :>> length = tankLength;
            :>> width = tankWidth;
            :>> height = tankHeight;
        }
        item centreTank : Loft {
            item aftWall : Section { :>> station = -tankLength / 2; :>> width = tankWidth * 0.8; :>> height = tankHeight * 0.85; :>> exponent = 5.0; }
            item aftFrame : Section { :>> station = -tankLength * 0.4; :>> width = tankWidth; :>> height = tankHeight; :>> exponent = 6.0; }
            item foreFrame : Section { :>> station = tankLength * 0.3; :>> width = tankWidth; :>> height = tankHeight; :>> exponent = 6.0; }
            item foreWall : Section { :>> station = tankLength / 2; :>> width = tankWidth * 0.62; :>> height = tankHeight * 0.8; :>> exponent = 4.0; }
        }
        item boostPumps : Rod {
            :>> pitchDeg = -90.0;
            :>> x = -tankLength / 2 + 0.3 [m];
            :>> y = tankWidth * 0.3;
            :>> z = -tankHeight / 2;
            :>> radius = 0.11 [m];
            :>> length = 0.3 [m];
            :>> mirror = MirrorPlane::xz;
        }
        @Placement { near = "airframe"; }
        @Budget { powerW = 30000.0; bus = "dc270"; }
        @Safety { asil = Asil::D; isolationGroup = "propulsion"; }
    }

    part def PowerThermalManagementSystem {
        doc /*
         * 270 V DC power conversion and distribution fed by both engine
         * generators, and the PAO liquid cooling loop. Heat leaves through
         * third stream air and fuel heat exchangers; their sum is the heat
         * rejection capacity. The body is the converter cabinet with the
         * plate fin third stream exchanger on its back and the PAO pump.
         */
        @Material { name = "aluminium heat exchanger and power electronics enclosure"; finish = Finish::anodizedAluminum; color = "#8a9099"; roughness = 0.5; }
        attribute generatorCapacity : PowerValue default 1000 [kW];
        attribute busVoltage : ElectricPotentialValue = 270 [V];
        attribute maxBusCurrent : ElectricCurrentValue = generatorCapacity / busVoltage;
        attribute thirdStreamRejection : PowerValue default 250 [kW];
        attribute fuelSinkRejection : PowerValue default 150 [kW];
        attribute heatRejectCapacity : PowerValue = thirdStreamRejection + fuelSinkRejection;
        attribute coolantFlow : VolumeFlowRateValue default 0.006 [m^3/s];
        attribute power : PowerValue default 45 [kW];
        attribute mass :> ISQ::mass default 1100 [kg];
        port genInLeft : ~GeneratorPort;
        port genInRight : ~GeneratorPort;
        port busOut : PowerPort { out :>> voltage = 270 [V]; }
        port coolantOut : CoolantPort { out :>> flowRate = coolantFlow; out :>> supplyTemperatureC = 18.0; }
        port fuelSinkLoop : CoolantPort { out :>> flowRate = 0.002 [m^3/s]; out :>> supplyTemperatureC = 45.0; }
        item envelope : RectangularCuboid {
            @Envelope { source = EnvelopeSource::stated; }
            :>> length = 2.2 [m];
            :>> width = 1.4 [m];
            :>> height = 0.9 [m];
        }
        item converterCabinet : Block {
            :>> x = 0.35 [m];
            :>> z = -0.05 [m];
            :>> length = 1.4 [m];
            :>> width = 1.3 [m];
            :>> height = 0.78 [m];
        }
        item exchangerPlates : Block {
            doc /* Third stream air to PAO plate fin exchanger. */
            :>> x = -0.4 [m];
            :>> length = 0.03 [m];
            :>> width = 1.36 [m];
            :>> height = 0.86 [m];
            :>> count = 12;
            :>> stepX = -0.055 [m];
        }
        item paoPump : Rod {
            :>> yawDeg = 90.0;
            :>> x = 0.7 [m];
            :>> z = 0.4 [m];
            :>> radius = 0.09 [m];
            :>> length = 0.9 [m];
        }
        @Placement { near = "engines"; }
        @Budget { powerW = 45000.0; heatW = -400000.0; bus = "dc270"; }
        @Safety { asil = Asil::D; isolationGroup = "power"; barrier = true; }
    }

    /* ------------------------------------------------------------ */
    /* Sensors                                                       */
    /* ------------------------------------------------------------ */

    part def ConformalAesaRadar {
        doc /*
         * Nose mounted GaN active electronically scanned array. The aperture
         * diameter follows the element count at half wavelength X band
         * pitch; array mass follows the element count plus the backend.
         */
        @Material { name = "glass fibre radome over GaN array"; finish = Finish::composite; color = "#4b5058"; roughness = 0.55; }
        attribute elementCount : Integer default 1600;
        attribute elementPitch : LengthValue = 0.016 [m];
        attribute apertureDiameter : LengthValue =
            (elementCount * 1.2732 * (elementPitch / (1 [m])) ** 2) ** 0.5 * (1 [m]);
        attribute detectionRange : LengthValue default 250 [km];
        attribute fieldOfRegardDeg : Real default 120.0;
        attribute power : PowerValue default 40 [kW];
        attribute heat : PowerValue = power * 0.8;
        attribute latency : DurationValue default 0.025 [s];
        attribute mass :> ISQ::mass = elementCount * 0.12 [kg] + 120 [kg];
        port missionData : MissionDataPort { out :>> dataRateMbps = 8000.0; }
        port powerIn : ~PowerPort { in :>> current = 148 [A]; }
        port coolant : ~CoolantPort { out :>> heatLoad = 32 [kW]; }
        item envelope : RectangularCuboid {
            @Envelope { source = EnvelopeSource::computed; rule = "face sized from the aperture diameter, depth of array and backend"; }
            :>> length = 0.5 [m];
            :>> width = apertureDiameter + 0.1 [m];
            :>> height = apertureDiameter + 0.1 [m];
        }
        item aperture : Extrude {
            doc /* The round radiating array face, looking forward along +x. */
            :>> x = 0.13 [m];
            :>> distance = 0.12 [m];
            item arrayFace : Section { :>> width = apertureDiameter; :>> height = apertureDiameter; }
        }
        item backend : Block {
            doc /* Receiver, exciter and power supply modules behind the array. */
            :>> x = -0.06 [m];
            :>> length = 0.38 [m];
            :>> width = apertureDiameter * 0.8;
            :>> height = apertureDiameter * 0.7;
        }
        item coldPlates : Block {
            doc /* Liquid cold plates between the transmit receive rows. */
            :>> x = 0.0 [m];
            :>> z = -apertureDiameter * 0.3;
            :>> length = 0.3 [m];
            :>> width = apertureDiameter * 0.85;
            :>> height = 0.02 [m];
            :>> count = 5;
            :>> stepZ = apertureDiameter * 0.15;
        }
        @Placement { anchor = Anchor::front; }
        @Budget { powerW = 40000.0; heatW = 32000.0; latencyMs = 25.0; dataRateMbps = 8000.0; bus = "dc270"; }
        @FieldOfView { horizontalDeg = 120.0; verticalDeg = 90.0; rangeM = 250000.0; minRangeM = 150.0; }
        @Safety { asil = Asil::C; isolationGroup = "mission"; }
    }

    part def DistributedApertureSensor {
        doc /*
         * One conformal electro optical and infrared aperture of the
         * distributed aperture system. Six of them, each about 95 degrees
         * square, give spherical situational awareness and missile launch
         * warning. The body is the sensor housing behind a faceted sapphire
         * window that sits flush with the skin.
         */
        @Material { name = "sapphire window in coated composite housing"; finish = Finish::glass; color = "#2c3138"; roughness = 0.2; }
        attribute frameRateHz : Real default 60.0;
        attribute detectionRange : LengthValue default 80 [km];
        attribute power : PowerValue default 400 [W];
        attribute heat : PowerValue = power * 0.95;
        attribute latency : DurationValue default 0.016 [s];
        attribute mass :> ISQ::mass default 8 [kg];
        port missionData : MissionDataPort { out :>> dataRateMbps = 2400.0; }
        port powerIn : ~PowerPort { in :>> current = 1.5 [A]; }
        item envelope : RectangularCuboid {
            @Envelope { source = EnvelopeSource::stated; }
            :>> length = 0.12 [m];
            :>> width = 0.25 [m];
            :>> height = 0.2 [m];
        }
        item housing : Block {
            :>> x = -0.02 [m];
            :>> length = 0.08 [m];
            :>> width = 0.2 [m];
            :>> height = 0.16 [m];
        }
        item window : Extrude {
            doc /* Hexagonal window on the look face. */
            :>> x = 0.02 [m];
            :>> distance = 0.04 [m];
            :>> taper = 0.85;
            item hexagon : Outline {
                item p1 : OutlinePoint { :>> u = 0.12 [m]; :>> v = 0 [m]; }
                item p2 : OutlinePoint { :>> u = 0.06 [m]; :>> v = 0.095 [m]; }
                item p3 : OutlinePoint { :>> u = -0.06 [m]; :>> v = 0.095 [m]; }
                item p4 : OutlinePoint { :>> u = -0.12 [m]; :>> v = 0 [m]; }
                item p5 : OutlinePoint { :>> u = -0.06 [m]; :>> v = -0.095 [m]; }
                item p6 : OutlinePoint { :>> u = 0.06 [m]; :>> v = -0.095 [m]; }
            }
        }
        @Budget { powerW = 400.0; heatW = 380.0; latencyMs = 16.0; dataRateMbps = 2400.0; bus = "dc270"; }
        @Safety { asil = Asil::C; isolationGroup = "mission"; }
    }

    part def ForwardDasAperture :> DistributedApertureSensor {
        doc /* Looks along the flight direction. */
        @Placement { anchor = Anchor::front; }
        @FieldOfView { horizontalDeg = 95.0; verticalDeg = 95.0; rangeM = 80000.0; minRangeM = 1.0; }
    }

    part def AftDasAperture :> DistributedApertureSensor {
        doc /* Looks behind the aircraft. */
        @Placement { anchor = Anchor::rear; yawDeg = 180.0; }
        @FieldOfView { horizontalDeg = 95.0; verticalDeg = 95.0; rangeM = 80000.0; minRangeM = 1.0; }
    }

    /* ------------------------------------------------------------ */
    /* Mission systems                                               */
    /* ------------------------------------------------------------ */

    part def MissionComputer {
        doc /*
         * Redundant open architecture mission and sensor fusion computer on
         * the fibre mission bus. Each processing lane adds a module to the
         * chassis; the switch fabric capacity bounds the sensor data it can
         * take in. It also sends flight guidance to the flight control
         * computer.
         */
        @Material { name = "anodised aluminium conduction cooled chassis"; finish = Finish::anodizedAluminum; color = "#454c55"; roughness = 0.55; }
        attribute processorCount : Integer default 4;
        attribute switchCapacityMbps : Real default 40000.0;
        attribute fusionLatency : DurationValue default 0.03 [s];
        attribute power : PowerValue default 12 [kW];
        attribute heat : PowerValue = power * 0.95;
        attribute mass :> ISQ::mass = processorCount * 18 [kg] + 30 [kg];
        port sensorIn : ~MissionDataPort { :>> linkCapacityMbps = 40000.0; }
        port displayOut : MissionDataPort { out :>> dataRateMbps = 2000.0; }
        port weaponsData : MissionDataPort { out :>> dataRateMbps = 50.0; }
        port cooperativeOut : MissionDataPort { out :>> dataRateMbps = 200.0; }
        port flightGuidance : MissionDataPort { out :>> dataRateMbps = 10.0; }
        port weaponControl : WeaponStationPort;
        port powerIn : ~PowerPort { in :>> current = 44.4 [A]; }
        port coolant : ~CoolantPort { out :>> heatLoad = 11.4 [kW]; }
        item envelope : RectangularCuboid {
            @Envelope { source = EnvelopeSource::computed; rule = "length grows with processing lanes"; }
            :>> length = processorCount * 0.12 [m] + 0.3 [m];
            :>> width = 0.5 [m];
            :>> height = 0.35 [m];
        }
        item chassis : Block {
            :>> length = processorCount * 0.12 [m] + 0.3 [m];
            :>> width = 0.44 [m];
            :>> height = 0.3 [m];
        }
        item laneModules : Block {
            doc /* One conduction cooled processing module per lane, wedge locked into the chassis. */
            :>> x = -(processorCount - 1) * 0.06 [m];
            :>> length = 0.09 [m];
            :>> width = 0.5 [m];
            :>> height = 0.35 [m];
            :>> count = processorCount;
            :>> stepX = 0.12 [m];
        }
        @Placement { near = "radar"; }
        @Budget { powerW = 12000.0; heatW = 11400.0; latencyMs = 30.0; dataRateMbps = -40000.0; bus = "dc270"; }
        @Safety { asil = Asil::D; isolationGroup = "mission"; failOperational = true; }
    }

    part def FlightControlComputer {
        doc /*
         * Triplex fly by wire flight control computer. It stabilises the
         * unstable tailless airframe and drives the four elevons; the electro
         * hydrostatic elevon actuators draw their 270 V power through its
         * actuator drive electronics, so its power includes the actuation.
         */
        @Material { name = "anodised aluminium chassis"; finish = Finish::anodizedAluminum; color = "#3f454d"; roughness = 0.5; }
        attribute laneCount : Integer default 3;
        attribute frameRateHz : Real default 400.0;
        attribute power : PowerValue default 16 [kW];
        attribute heat : PowerValue = power * 0.1;
        attribute mass :> ISQ::mass default 45 [kg];
        port guidanceIn : ~MissionDataPort;
        port surfaceCommand : ActuatorPort;
        port powerIn : ~PowerPort { in :>> current = 59.3 [A]; }
        item envelope : RectangularCuboid {
            @Envelope { source = EnvelopeSource::computed; rule = "one 0.13 m lane per channel plus the drive electronics"; }
            :>> length = 0.45 [m];
            :>> width = laneCount * 0.13 [m];
            :>> height = 0.3 [m];
        }
        item lanes : Block {
            doc /* Dissimilar redundant channels, each in its own sealed box. */
            :>> y = -(laneCount - 1) * 0.065 [m];
            :>> length = 0.42 [m];
            :>> width = 0.11 [m];
            :>> height = 0.28 [m];
            :>> count = laneCount;
            :>> stepY = 0.13 [m];
        }
        @Placement { near = "missionComputer"; }
        @Budget { powerW = 16000.0; heatW = 1600.0; latencyMs = 2.5; bus = "dc270"; }
        @Safety { asil = Asil::D; isolationGroup = "flightControl"; failOperational = true; barrier = true; }
    }

    part def EjectionSeat {
        doc /* Zero zero rocket assisted ejection seat: bucket, reclined back, headbox and catapult rails. */
        @Material { name = "aluminium frame with fabric cushions"; finish = Finish::paint; color = "#3a3f36"; roughness = 0.75; }
        attribute mass :> ISQ::mass default 95 [kg];
        item envelope : RectangularCuboid {
            @Envelope { source = EnvelopeSource::stated; }
            :>> length = 0.75 [m];
            :>> width = 0.65 [m];
            :>> height = 1.3 [m];
        }
        item bucket : Block {
            :>> x = 0.08 [m];
            :>> z = -0.38 [m];
            :>> length = 0.5 [m];
            :>> width = 0.52 [m];
            :>> height = 0.16 [m];
        }
        item back : Block {
            :>> x = -0.2 [m];
            :>> z = 0.05 [m];
            :>> pitchDeg = -15.0;
            :>> length = 0.12 [m];
            :>> width = 0.5 [m];
            :>> height = 0.8 [m];
        }
        item headbox : Block {
            :>> x = -0.3 [m];
            :>> z = 0.52 [m];
            :>> pitchDeg = -15.0;
            :>> length = 0.22 [m];
            :>> width = 0.36 [m];
            :>> height = 0.26 [m];
        }
        item rails : Rod {
            :>> x = -0.3 [m];
            :>> y = 0.27 [m];
            :>> pitchDeg = -75.0;
            :>> radius = 0.025 [m];
            :>> length = 1.1 [m];
            :>> mirror = MirrorPlane::xz;
        }
        @Placement { anchor = Anchor::bottom; }
    }

    part def Canopy {
        doc /* One piece low observable canopy, metallised against radar returns from the cockpit. */
        @Material { name = "metallised polycarbonate"; finish = Finish::glass; color = "#8a7a48"; roughness = 0.08; transmission = 0.55; }
        attribute mass :> ISQ::mass default 80 [kg];
        item envelope : RectangularCuboid {
            @Envelope { source = EnvelopeSource::stated; }
            :>> length = 3.0 [m];
            :>> width = 1.0 [m];
            :>> height = 0.6 [m];
        }
        item bubble : Loft {
            item aftFairing : Section { :>> station = -1.5 [m]; :>> width = 0.36 [m]; :>> height = 0.14 [m]; :>> cv = -0.23 [m]; }
            item aftBow : Section { :>> station = -0.9 [m]; :>> width = 0.86 [m]; :>> height = 0.48 [m]; :>> cv = -0.06 [m]; }
            item peak : Section { :>> station = 0.05 [m]; :>> width = 0.98 [m]; :>> height = 0.6 [m]; :>> cv = 0 [m]; }
            item windscreen : Section { :>> station = 0.9 [m]; :>> width = 0.8 [m]; :>> height = 0.42 [m]; :>> cv = -0.09 [m]; }
            item point : Section { :>> station = 1.5 [m]; :>> width = 0.1 [m]; :>> height = 0.05 [m]; :>> cv = -0.27 [m]; }
        }
    }

    part def CrewStation {
        doc /*
         * Optionally manned cockpit module: a pressurised tub with an
         * ejection seat and a wide area display under a low observable
         * canopy. Flown unmanned, the seat bay carries mission equipment.
         */
        @Material { name = "coated composite tub"; finish = Finish::composite; color = "#3e434a"; roughness = 0.4; }
        attribute optionallyManned : Boolean default true;
        attribute crewCount : Integer default 1;
        attribute displayWidth : LengthValue default 0.5 [m];
        attribute pressureDifferential : PressureValue default 34000 [Pa];
        attribute power : PowerValue default 4 [kW];
        attribute heat : PowerValue = power * 0.875;
        attribute mass :> ISQ::mass = 440 [kg] + canopy.mass + seat.mass;
        part seat : EjectionSeat {
            @Placement { mode = LayoutMode::fixed; xM = -0.25; yM = 0.0; zM = -0.05; }
        }
        part canopy : Canopy {
            @Placement { mode = LayoutMode::fixed; xM = 0.0; yM = 0.0; zM = 0.4; }
        }
        port powerIn : ~PowerPort { in :>> current = 14.8 [A]; }
        port displayIn : ~MissionDataPort;
        item envelope : RectangularCuboid {
            @Envelope { source = EnvelopeSource::stated; hollow = true; wallThicknessM = 0.008; }
            :>> length = 3.0 [m];
            :>> width = 1.1 [m];
            :>> height = 1.4 [m];
        }
        item tub : Block {
            :>> z = -0.35 [m];
            :>> length = 2.7 [m];
            :>> width = 1.0 [m];
            :>> height = 0.7 [m];
        }
        item glareshield : Block {
            doc /* Wide area display under its glareshield. */
            :>> x = 0.62 [m];
            :>> z = 0.12 [m];
            :>> length = 0.35 [m];
            :>> width = displayWidth * 1.5;
            :>> height = 0.22 [m];
        }
        @Placement { anchor = Anchor::top; near = "radar"; }
        @Budget { powerW = 4000.0; heatW = 3500.0; bus = "dc270"; }
        @Safety { asil = Asil::C; isolationGroup = "mission"; }
    }

    part def CcaDatalink {
        doc /*
         * Low probability of intercept directional Ka band datalink with
         * conformal apertures. Commands up to four collaborative combat
         * aircraft and shares track data with them.
         */
        @Material { name = "conformal composite antenna panel"; finish = Finish::composite; color = "#50565e"; roughness = 0.6; }
        attribute maxCcaCount : Integer default 4;
        attribute linkRange : LengthValue default 400 [km];
        attribute linkRateMbps : Real default 400.0;
        attribute carrierHz : Real = 33000000000.0;
        attribute latency : DurationValue default 0.005 [s];
        attribute power : PowerValue default 3 [kW];
        attribute heat : PowerValue = power * 0.8;
        attribute mass :> ISQ::mass default 45 [kg];
        port missionData : MissionDataPort { out :>> dataRateMbps = 400.0; }
        port commandIn : ~MissionDataPort;
        port powerIn : ~PowerPort { in :>> current = 11.1 [A]; }
        port coolant : ~CoolantPort { out :>> heatLoad = 2.4 [kW]; }
        item envelope : RectangularCuboid {
            @Envelope { source = EnvelopeSource::stated; }
            :>> length = 0.6 [m];
            :>> width = 0.4 [m];
            :>> height = 0.08 [m];
        }
        item panel : Extrude {
            doc /* Diamond conformal panel, edges aligned with the planform. */
            :>> pitchDeg = -90.0;
            :>> z = -0.04 [m];
            :>> distance = 0.08 [m];
            :>> taper = 0.9;
            item diamond : Outline {
                item fore : OutlinePoint { :>> u = 0 [m]; :>> v = -0.3 [m]; }
                item left : OutlinePoint { :>> u = 0.2 [m]; :>> v = 0 [m]; }
                item aft : OutlinePoint { :>> u = 0 [m]; :>> v = 0.3 [m]; }
                item right : OutlinePoint { :>> u = -0.2 [m]; :>> v = 0 [m]; }
            }
        }
        @Placement { anchor = Anchor::top; }
        @Budget { powerW = 3000.0; heatW = 2400.0; latencyMs = 5.0; dataRateMbps = 400.0; bus = "dc270"; }
        @FieldOfView { horizontalDeg = 360.0; verticalDeg = 60.0; rangeM = 400000.0; }
        @Safety { asil = Asil::C; isolationGroup = "mission"; }
    }

    /* ------------------------------------------------------------ */
    /* Landing gear                                                  */
    /* ------------------------------------------------------------ */

    part def GearWheel {
        doc /* Wheel and tyre on the gear axle; the axle runs along y. */
        @Material { name = "tyre rubber on a forged aluminium hub"; finish = Finish::rubber; color = "#2a2c2f"; roughness = 0.85; }
        attribute mass :> ISQ::mass;
        attribute wheelRadius : LengthValue;
        attribute tyreWidth : LengthValue;
        item envelope : RightCircularCylinder {
            @Envelope { source = EnvelopeSource::computed; rule = "wheel radius by tyre width"; }
            :>> radius = wheelRadius;
            :>> height = tyreWidth;
        }
        item tyre : Revolve {
            :>> yawDeg = 90.0;
            item carcass : Section { :>> width = tyreWidth; :>> height = wheelRadius * 0.62; :>> cv = wheelRadius * 0.69; :>> exponent = 2.6; }
        }
        item hub : Revolve {
            :>> yawDeg = 90.0;
            item rim : Section { :>> width = tyreWidth * 0.8; :>> height = wheelRadius * 0.42; :>> cv = wheelRadius * 0.21; :>> exponent = 4.0; }
        }
    }

    part def LandingGear {
        doc /*
         * One retractable gear leg: an oleo strut with its piston, axle,
         * drag brace and torque links on a single wheel. The envelope and the
         * bodies are sized from the wheel radius and strut length the nose
         * and main gear state.
         */
        @Material { name = "high strength steel"; finish = Finish::metal; color = "#a3a8ad"; roughness = 0.3; }
        attribute mass :> ISQ::mass;
        attribute wheelRadius : LengthValue;
        attribute strutLength : LengthValue;
        attribute staticLoadRating : ForceValue;
        attribute axleHeight : LengthValue = wheelRadius - (strutLength + wheelRadius) / 2;
        attribute legTop : LengthValue = (strutLength + wheelRadius) / 2;
        item envelope : RightCircularCylinder {
            @Envelope { source = EnvelopeSource::computed; rule = "wheel radius and strut length"; }
            :>> radius = wheelRadius;
            :>> height = strutLength + wheelRadius;
        }
        item strut : Extrude {
            doc /* Oleo cylinder from mid stroke up to the trunnion at the envelope top. */
            :>> pitchDeg = -90.0;
            :>> z = axleHeight + strutLength * 0.35;
            :>> distance = strutLength * 0.65;
            item tube : Section { :>> width = wheelRadius * 0.3; :>> height = wheelRadius * 0.3; }
        }
        item piston : Rod {
            doc /* Chromed sliding piston down to the axle. */
            :>> pitchDeg = -90.0;
            :>> z = axleHeight + strutLength * 0.2;
            :>> radius = wheelRadius * 0.1;
            :>> length = strutLength * 0.4;
        }
        item axle : Rod {
            :>> yawDeg = 90.0;
            :>> z = axleHeight;
            :>> radius = wheelRadius * 0.08;
            :>> length = wheelRadius * 0.9;
        }
        item trunnion : Rod {
            :>> yawDeg = 90.0;
            :>> z = legTop - wheelRadius * 0.12;
            :>> radius = wheelRadius * 0.1;
            :>> length = wheelRadius * 1.2;
        }
        item dragBrace : Rod {
            doc /* Folding drag brace from mid strut forward and up to the wheel well. */
            :>> x = strutLength * 0.17;
            :>> z = legTop - strutLength * 0.22;
            :>> pitchDeg = -50.0;
            :>> radius = wheelRadius * 0.06;
            :>> length = strutLength * 0.55;
        }
        item torqueLinks : Block {
            :>> x = -wheelRadius * 0.22;
            :>> z = axleHeight + strutLength * 0.3;
            :>> pitchDeg = 30.0;
            :>> length = wheelRadius * 0.4;
            :>> width = 0.04 [m];
            :>> height = 0.06 [m];
        }
        @Placement { anchor = Anchor::bottom; }
        @Safety { asil = Asil::C; }
    }

    part def NoseGear :> LandingGear {
        doc /* Steerable nose leg. */
        attribute :>> mass = 205 [kg] + wheel.mass;
        attribute :>> wheelRadius = 0.33 [m];
        attribute :>> strutLength = 1.5 [m];
        attribute :>> staticLoadRating = 120000 [N];
        part wheel : GearWheel {
            :>> mass = 35 [kg];
            :>> wheelRadius = 0.33 [m];
            :>> tyreWidth = 0.2 [m];
            @Placement { mode = LayoutMode::fixed; xM = 0.0; yM = 0.0; zM = -0.585; }
        }
    }

    part def MainGear :> LandingGear {
        doc /* Main leg, one each side, with carbon brakes. */
        attribute :>> mass = 360 [kg] + wheel.mass;
        attribute :>> wheelRadius = 0.48 [m];
        attribute :>> strutLength = 1.35 [m];
        attribute :>> staticLoadRating = 260000 [N];
        part wheel : GearWheel {
            :>> mass = 70 [kg];
            :>> wheelRadius = 0.48 [m];
            :>> tyreWidth = 0.3 [m];
            @Placement { mode = LayoutMode::fixed; xM = 0.0; yM = 0.0; zM = -0.435; }
        }
    }
}

package SixthGenFighter {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import ShapeItems::*;
    private import TradeStudies::*;
    private import MBEstudio::*;
    private import SixthGenFighterInterfaces::*;
    private import SixthGenFighterParts::*;

    /* ------------------------------------------------------------ */
    /* System                                                        */
    /* ------------------------------------------------------------ */

    part def Fighter {
        doc /*
         * Tailless, low observable, twin adaptive cycle engine air dominance
         * fighter. Masses roll up from the parts; takeoff mass carries full
         * internal fuel and six missiles, combat mass half the internal fuel.
         * Combat radius is a Breguet style estimate at a Mach 0.9 high
         * altitude cruise: the fuel left after the combat allowance and the
         * reserve, with the logarithm taken to second order, flown out and
         * back. Electrical and heat loads sum the mission systems on the
         * 270 V DC bus and the PAO loop. The sensor to shooter latency is
         * the radar dwell, the mission bus hop, the fusion cycle and the
         * weapon station release.
         */
        @Placement { mode = LayoutMode::fixed; }

        attribute mtowLimit : MassValue = 45000 [kg];
        attribute internalFuel : MassValue default 16000 [kg];
        attribute cruiseSpeedKmh : Real default 950.0;
        attribute combatAllowance : Real default 0.25;
        attribute reserveFraction : Real default 0.10;
        attribute wingLoadingLimit : Real = 450.0;
        attribute masterArm : Boolean default false;
        attribute supercruising : Boolean default false;

        attribute emptyMass : MassValue = airframe.mass + leftEngine.mass + rightEngine.mass
            + weaponsBay.mass + fuelSystem.mass + ptms.mass + radar.mass
            + 2 * forwardDas.mass + 2 * aftDas.mass + 2 * sideDas.mass
            + missionComputer.mass + crewStation.mass + datalink.mass
            + flightControls.mass + noseGear.mass + leftMainGear.mass + rightMainGear.mass;
        attribute takeoffMass : MassValue = emptyMass + internalFuel + weaponsBay.storesMass;
        attribute combatMass : MassValue = emptyMass + 0.5 * internalFuel + weaponsBay.storesMass;
        attribute totalMaxThrust : ForceValue = leftEngine.maxThrust + rightEngine.maxThrust;
        attribute thrustToWeight : Real = totalMaxThrust / (1 [N]) / (combatMass / (1 [kg]) * 9.81);
        attribute wingLoading : Real = takeoffMass / (1 [kg]) / (airframe.wingArea / (1 [m * m]));

        attribute cruiseFuelFraction : Real = internalFuel * (1 - combatAllowance - reserveFraction) / takeoffMass;
        attribute combatRadiusKm : Real = cruiseSpeedKmh / leftEngine.tsfcPerHour * airframe.liftToDrag
            * (cruiseFuelFraction + cruiseFuelFraction * cruiseFuelFraction / 2) / 2;

        attribute electricalLoad : PowerValue = radar.power
            + 2 * forwardDas.power + 2 * aftDas.power + 2 * sideDas.power
            + missionComputer.power + datalink.power + crewStation.power
            + weaponsBay.power + fuelSystem.power + ptms.power + flightControls.power;
        attribute totalHeatLoad : PowerValue = radar.heat
            + 2 * forwardDas.heat + 2 * aftDas.heat + 2 * sideDas.heat
            + missionComputer.heat + datalink.heat + crewStation.heat + flightControls.heat;
        attribute sensorToShooterLatency : DurationValue = radar.latency + radar.missionData.hopLatency
            + missionComputer.fusionLatency + weaponsBay.releaseLatency;
        attribute totalSensorDataMbps : Real = radar.missionData.dataRateMbps
            + 2 * forwardDas.missionData.dataRateMbps + 2 * aftDas.missionData.dataRateMbps
            + 2 * sideDas.missionData.dataRateMbps + datalink.missionData.dataRateMbps;

        part airframe : BlendedWingBody { @Placement { xM = 0.0; yM = 0.0; zM = 0.0; } }
        part leftEngine : AdaptiveCycleEngine {
            @Safety { asil = Asil::D; isolationGroup = "propulsion"; }
            @Placement { xM = -8.05; yM = 1.25; zM = 0.0; }
        }
        part rightEngine : AdaptiveCycleEngine {
            @Safety { asil = Asil::D; isolationGroup = "propulsion"; }
            @Placement { xM = -8.05; yM = -1.25; zM = 0.0; }
        }
        part weaponsBay : InternalWeaponsBay { @Placement { xM = 0.4; yM = 0.0; zM = -0.57; } }
        part fuelSystem : FuelSystem { @Placement { xM = 0.6; yM = 0.0; zM = 0.43; } }
        part ptms : PowerThermalManagementSystem { @Placement { xM = -4.0; yM = 0.0; zM = 0.1; } }
        part radar : ConformalAesaRadar { @Placement { mode = LayoutMode::fixed; xM = 9.2; yM = 0.0; zM = -0.05; } }
        part forwardDas : ForwardDasAperture[2] { @Placement { mode = LayoutMode::fixed; xM = 8.7; yM = 0.35; zM = 0.48; } }
        part aftDas : AftDasAperture[2] { @Placement { mode = LayoutMode::fixed; xM = -9.5; yM = 0.3; zM = 0.57; yawDeg = 180.0; } }
        part sideDas : DistributedApertureSensor[2] {
            doc /* Side looking apertures, one each side, completing the spherical coverage. */
            @Placement { mode = LayoutMode::fixed; xM = 2.0; yM = 2.0; zM = 0.06; yawDeg = 90.0; }
            @FieldOfView { horizontalDeg = 95.0; verticalDeg = 95.0; rangeM = 80000.0; minRangeM = 1.0; }
        }
        part missionComputer : MissionComputer { @Placement { xM = 7.9; yM = 0.0; zM = -0.42; } }
        part flightControls : FlightControlComputer { @Placement { xM = 5.2; yM = 0.0; zM = -0.35; } }
        part crewStation : CrewStation { @Placement { mode = LayoutMode::fixed; xM = 7.0; yM = 0.0; zM = 0.55; } }
        part datalink : CcaDatalink { @Placement { mode = LayoutMode::fixed; xM = -3.0; yM = 0.0; zM = 1.02; } }
        part noseGear : NoseGear { @Placement { mode = LayoutMode::fixed; xM = 6.0; yM = 0.0; zM = -1.845; } }
        part leftMainGear : MainGear { @Placement { mode = LayoutMode::fixed; xM = -2.5; yM = 1.6; zM = -1.845; } }
        part rightMainGear : MainGear { @Placement { mode = LayoutMode::fixed; xM = -2.5; yM = -1.6; zM = -1.845; } }

        interface leftThrustMount : EngineMount connect airframe ::> airframe.engineMount to engine ::> leftEngine.mount;
        interface rightThrustMount : EngineMount connect airframe ::> airframe.engineMount to engine ::> rightEngine.mount;

        interface leftFuelFeed : FuelLine connect tank ::> fuelSystem.feedLeft to feed ::> leftEngine.fuelIn;
        interface rightFuelFeed : FuelLine connect tank ::> fuelSystem.feedRight to feed ::> rightEngine.fuelIn;

        interface leftGenerator : ShaftPowerLink connect generator ::> leftEngine.genOut to consumer ::> ptms.genInLeft;
        interface rightGenerator : ShaftPowerLink connect generator ::> rightEngine.genOut to consumer ::> ptms.genInRight;

        interface radarPower : PowerLink connect supplier ::> ptms.busOut to consumer ::> radar.powerIn;
        interface forwardDasPower : PowerLink connect supplier ::> ptms.busOut to consumer ::> forwardDas.powerIn;
        interface aftDasPower : PowerLink connect supplier ::> ptms.busOut to consumer ::> aftDas.powerIn;
        interface sideDasPower : PowerLink connect supplier ::> ptms.busOut to consumer ::> sideDas.powerIn;
        interface computerPower : PowerLink connect supplier ::> ptms.busOut to consumer ::> missionComputer.powerIn;
        interface datalinkPower : PowerLink connect supplier ::> ptms.busOut to consumer ::> datalink.powerIn;
        interface cockpitPower : PowerLink connect supplier ::> ptms.busOut to consumer ::> crewStation.powerIn;
        interface bayPower : PowerLink connect supplier ::> ptms.busOut to consumer ::> weaponsBay.powerIn;
        interface pumpPower : PowerLink connect supplier ::> ptms.busOut to consumer ::> fuelSystem.powerIn;

        interface radarCooling : CoolantLoop connect supply ::> ptms.coolantOut to consumer ::> radar.coolant;
        interface computerCooling : CoolantLoop connect supply ::> ptms.coolantOut to consumer ::> missionComputer.coolant;
        interface datalinkCooling : CoolantLoop connect supply ::> ptms.coolantOut to consumer ::> datalink.coolant;
        interface fuelHeatSink : CoolantLoop connect supply ::> ptms.fuelSinkLoop to consumer ::> fuelSystem.heatSink;

        interface radarTracks : MissionBus connect source ::> radar.missionData to sink ::> missionComputer.sensorIn;
        interface forwardDasVideo : MissionBus connect source ::> forwardDas.missionData to sink ::> missionComputer.sensorIn;
        interface aftDasVideo : MissionBus connect source ::> aftDas.missionData to sink ::> missionComputer.sensorIn;
        interface sideDasVideo : MissionBus connect source ::> sideDas.missionData to sink ::> missionComputer.sensorIn;
        interface cooperativeTracks : MissionBus connect source ::> datalink.missionData to sink ::> missionComputer.sensorIn;
        interface cockpitDisplay : MissionBus connect source ::> missionComputer.displayOut to sink ::> crewStation.displayIn;
        interface bayData : MissionBus connect source ::> missionComputer.weaponsData to sink ::> weaponsBay.missionData;
        interface ccaCommands : MissionBus connect source ::> missionComputer.cooperativeOut to sink ::> datalink.commandIn;

        interface flightControlPower : PowerLink connect supplier ::> ptms.busOut to consumer ::> flightControls.powerIn;
        interface flightGuidance : MissionBus connect source ::> missionComputer.flightGuidance to sink ::> flightControls.guidanceIn;
        interface leftInboardDrive : ActuatorLink connect command ::> flightControls.surfaceCommand to drive ::> airframe.leftInboardElevon.drive;
        interface rightInboardDrive : ActuatorLink connect command ::> flightControls.surfaceCommand to drive ::> airframe.rightInboardElevon.drive;
        interface leftOuterDrive : ActuatorLink connect command ::> flightControls.surfaceCommand to drive ::> airframe.leftOuterElevon.drive;
        interface rightOuterDrive : ActuatorLink connect command ::> flightControls.surfaceCommand to drive ::> airframe.rightOuterElevon.drive;

        interface storeManagement : WeaponStationLink connect controller ::> missionComputer.weaponControl to bay ::> weaponsBay.stations;

        constraint massWithinLimit { takeoffMass <= mtowLimit }
        constraint thrustMargin { thrustToWeight >= 1.1 }
        constraint heatRejected { totalHeatLoad <= ptms.heatRejectCapacity }
        constraint electricalCovered { electricalLoad <= 0.9 * ptms.generatorCapacity }
        constraint fuelFits { internalFuel <= fuelSystem.capacity }
        constraint sensorToShooterFast { sensorToShooterLatency <= 0.1 [s] }
        constraint busWithinCapacity { totalSensorDataMbps <= 0.8 * missionComputer.switchCapacityMbps }
        constraint wingLoadingOk { wingLoading <= wingLoadingLimit }

        state flightModes {
            doc /* A state usage, so its assignments read the fighter's own features. */
            entry; then parked;
            state parked { entry assign masterArm := false; }
            state taxiOut;
            state takeoffRoll;
            state ingress { entry assign supercruising := true; }
            state engagement { entry assign masterArm := true; }
            state egress { entry assign masterArm := false; }
            state recovery { entry assign supercruising := false; }
            transition startTaxi first parked accept after 600 [s] then taxiOut;
            transition lineUp first taxiOut accept after 300 [s] then takeoffRoll;
            transition airborne first takeoffRoll accept after 30 [s] then ingress;
            transition commit first ingress accept after 3600 [s] then engagement;
            transition disengage first engagement accept after 300 [s] then egress;
            transition abortMission first ingress then egress;
            transition homePlate first egress accept after 3600 [s] then recovery;
            transition shutdown first recovery accept after 600 [s] then parked;
        }
    }

    /* ------------------------------------------------------------ */
    /* Variants                                                       */
    /* ------------------------------------------------------------ */

    variation part def EngineOption :> AdaptiveCycleEngine {
        variant part balancedAdaptive : AdaptiveCycleEngine {
            :>> maxThrust = 200000 [N]; :>> mass = 3700 [kg]; :>> tsfcPerHour = 0.62; :>> thirdStreamBypass = 0.6;
        }
        variant part enduranceBiased : AdaptiveCycleEngine {
            :>> maxThrust = 185000 [N]; :>> mass = 3800 [kg]; :>> tsfcPerHour = 0.55; :>> thirdStreamBypass = 0.9;
        }
        variant part thrustBiased : AdaptiveCycleEngine {
            :>> maxThrust = 225000 [N]; :>> mass = 3950 [kg]; :>> tsfcPerHour = 0.70; :>> thirdStreamBypass = 0.4;
        }
    }

    part airDominanceFighter : Fighter {
        @LoadCase { name = "1 g level flight"; nzG = -1.0; }
        @LoadCase { name = "9 g sustained turn"; nzG = -9.0; factor = 1.5; }
        part :>> leftEngine : EngineOption;
        part :>> rightEngine : EngineOption;
    }

    /* ------------------------------------------------------------ */
    /* Requirements                                                   */
    /* ------------------------------------------------------------ */

    requirement def <'FX-R1'> CombatRadiusRequirement {
        doc /* While carrying a full internal weapons load on internal fuel only, the fighter shall have a combat radius of at least 1800 km. */
        subject f : Fighter;
        attribute minRadius : Real = 1800.0;
        require constraint { f.combatRadiusKm >= minRadius }
    }

    requirement def <'FX-R2'> TakeoffMassRequirement {
        doc /* The fighter maximum takeoff mass, with full internal fuel and six missiles, shall not exceed 45000 kg. */
        subject f : Fighter;
        require constraint { f.takeoffMass <= 45000 [kg] }
    }

    requirement def <'FX-R3'> ThrustToWeightRequirement {
        doc /* While at combat mass with 50 percent internal fuel and full weapons, the fighter shall provide total maximum thrust of at least 1.1 times its weight. */
        subject f : Fighter;
        attribute minRatio : Real = 1.1;
        require constraint { f.thrustToWeight >= minRatio }
    }

    requirement def <'FX-R4'> ThermalRequirement {
        doc /* While all mission systems are operating, the thermal management system shall reject the total mission heat load of radar, mission computer, datalink and avionics. */
        subject f : Fighter;
        require constraint { f.totalHeatLoad <= f.ptms.heatRejectCapacity }
    }

    requirement def <'FX-R5'> ElectricalRequirement {
        doc /* While all mission systems are operating, the mission electrical load shall not exceed 90 percent of the combined engine generator capacity. */
        subject f : Fighter;
        require constraint { f.electricalLoad <= 0.9 * (f.leftEngine.generatorRating + f.rightEngine.generatorRating) }
    }

    requirement def <'FX-R6'> SensorToShooterRequirement {
        doc /* When the radar detects a target, the fighter shall issue a weapon release cue within 0.1 s through the radar, mission bus, fusion and weapon station chain. */
        subject f : Fighter;
        require constraint { f.sensorToShooterLatency <= 0.1 [s] }
    }

    requirement def <'FX-R7'> MissionBandwidthRequirement {
        doc /* While all sensors are streaming, the total sensor data on the mission bus shall use no more than 80 percent of the mission computer switching capacity. */
        subject f : Fighter;
        require constraint { f.totalSensorDataMbps <= 0.8 * f.missionComputer.switchCapacityMbps }
    }

    requirement radiusReq : CombatRadiusRequirement;
    requirement takeoffMassReq : TakeoffMassRequirement;
    requirement thrustReq : ThrustToWeightRequirement;
    requirement thermalReq : ThermalRequirement;
    requirement electricalReq : ElectricalRequirement;
    requirement killChainReq : SensorToShooterRequirement;
    requirement bandwidthReq : MissionBandwidthRequirement;

    satisfy radiusReq by airDominanceFighter;
    satisfy takeoffMassReq by airDominanceFighter;
    satisfy thrustReq by airDominanceFighter;
    satisfy thermalReq by airDominanceFighter;
    satisfy electricalReq by airDominanceFighter;
    satisfy killChainReq by airDominanceFighter;
    satisfy bandwidthReq by airDominanceFighter;

    /* ------------------------------------------------------------ */
    /* Trade study                                                    */
    /* ------------------------------------------------------------ */

    calc def CombatRadiusWithEngine {
        doc /*
         * Combat radius in km with two of this engine: 31377 kg takeoff mass
         * without engines (14417 kg dry, 16000 kg fuel, 960 kg missiles),
         * 10400 kg cruise fuel after the combat allowance and reserve,
         * 950 km/h cruise, lift to drag 10, out and back.
         */
        in eng : AdaptiveCycleEngine;
        return r : Real = 950.0 / eng.tsfcPerHour * 10.0
            * (10400.0 / (31377.0 + 2 * eng.mass / (1 [kg]))
               + (10400.0 / (31377.0 + 2 * eng.mass / (1 [kg]))) ** 2 / 2) / 2;
    }

    calc def CombatThrustToWeight {
        doc /* Thrust to weight at combat mass: 23377 kg without engines (dry, half fuel, missiles) plus two engines. */
        in eng : AdaptiveCycleEngine;
        return t : Real = 2 * eng.maxThrust / (1 [N]) / ((23377.0 + 2 * eng.mass / (1 [kg])) * 9.81);
    }

    calc def InstalledPropulsionMass {
        in eng : AdaptiveCycleEngine;
        return m : MassValue = 2 * eng.mass;
    }

    analysis engineTrade : TradeStudy {
        doc /* Choose an adaptive cycle engine: maximise combat radius and combat thrust to weight, minimise installed propulsion mass. */
        subject : AdaptiveCycleEngine[3] = (EngineOption::balancedAdaptive, EngineOption::enduranceBiased, EngineOption::thrustBiased);
        objective : MaximizeObjective;
        calc :>> evaluationFunction {
            in ref alternative : AdaptiveCycleEngine;
            return attribute score : Real = CombatRadiusWithEngine(alternative);
        }
        calc combatRadius : CombatRadiusWithEngine { @Objective { sense = Sense::maximize; weight = 0.4; unit = "km"; } }
        calc thrustRatio : CombatThrustToWeight { @Objective { sense = Sense::maximize; weight = 0.35; unit = "1"; } }
        calc propulsionMass : InstalledPropulsionMass { @Objective { sense = Sense::minimize; weight = 0.25; unit = "kg"; } }
    }
}
