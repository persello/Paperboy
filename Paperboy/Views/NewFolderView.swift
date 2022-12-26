//
//  NewFolderView.swift
//  Paperboy
//
//  Created by Riccardo Persello on 24/12/22.
//

import SwiftUI
import SFSafeSymbols

struct NewFolderView: View {
    @Environment(\.managedObjectContext) private var context
    
    @Binding var modalShown: Bool
    
    @State private var icon: SFSymbol = .folder
    @State private var name: String = ""
        
    private let symbols: [SFSymbol] = [
        // Communication
        .mic, .bubbleLeft, .quoteBubble, .phone, .envelope, .envelopeOpen, .waveform, .recordingtape,
        
        // Weather
        .sunMax, .sunHaze, .moon, .moonHaze, .sparkles, .moonStars, .cloud, .cloudRain, .cloudFog, .cloudSnow, .cloudBolt, .cloudSun, .cloudSunRain, .cloudMoon, .cloudMoonRain, .smoke, .wind, .snowflake, .tornado, .tropicalstorm, .thermometerSun, .thermometerMedium, .aqiMedium, .humidity,
        
        // Objects & Tools
        .pencil, .pencilLine, .eraser, .trash, .folder, .questionmarkFolder, .tray, .trayFull, .tray2, .externaldrive, .xmarkBin, .doc, .docOnDoc, .clipboard, .note, .book, .booksVertical, .bookClosed, .menucard, .greetingcard, .magazine, .newspaper, .bookmark, .graduationcap, .pencilAndRuler, .ruler, .backpack, .paperclip, .link, .dumbbell, .soccerball, .baseball, .basketball, .football, .tennisRacket, .hockeyPuck, .cricketBall, .tennisball, .volleyball, .rosette, .trophy, .medal, .beachUmbrella, .umbrella, .megaphone, .speaker, .musicMic, .magnifyingglass, .shield, .flag, .flag2Crossed, .bell, .tag, .camera, .gearshape2, .scissors, .bag, .cart, .basket, .creditcard, .walletPass, .wandAndStars, .dialLow, .gyroscope, .gaugeHigh, .speedometer, .barometer, .metronome, .amplifier, .dice, .pianokeys, .tuningfork, .paintbrush, .paintbrushPointed, .level, .wrenchAdjustable, .hammer, .screwdriver, .eyedropper, .wrenchAndScrewdriver, .scroll, .stethoscope, .printer, .scanner, .faxmachine, /* .handbag,*/ .briefcase, .case, .latch2Case, .crossCase, .suitcase, .suitcaseCart, /*.suitcaseRolling,*/ .theatermasks, /*.theatermasksBrush,*/ .puzzlepiece, .lightbulb, .fanblades, .lampDesk, .lampTable, .lightBeaconMax, .webCamera, .bathtub, .partyPopper, .balloon2, .fryingPan, .bedDouble, .sofa, .chairLounge, .chair, .cabinet, .fireplace, .washer, .oven, .stove, .cooktop, .microwave, .refrigerator, .tent, .signpostLeft, .building2, .lock, .key, .pin, .mappin, .map, .powerplug, .cpu, .memorychip, .opticaldisc, .headphones, .radio, .guitars, .sailboat, .fuelpump, .boltBatteryblock, .medicalThermometer, .bandage, .syringe, .facemask, .pills, .testtube2, .crossVial, .teddybear, /*.tree,*/ .tshirt, .film, .ticket, .comb, .eyeglasses, .crown, .shippingbox, .clock, .deskclock, .alarm, .stopwatch, .chartXyaxisLine, .timer, .gamecontroller, .paintpalette, .swatchpalette, .cupAndSaucer, .wineglass, .forkKnife, .scalemass, .compassDrawing, .globeDesk, .fossilShell, .gift, .hourglass, .lifepreserver, .binoculars,
        
        // Devices
        .keyboard, .display, .display2, .desktopcomputer, .pc, .serverRack, .laptopcomputer, .flipphone, .candybarphone, .computermouse, .earbuds, .hifispeaker2, .mediastick, .cableConnector, .tv, .car,
        
        // Camera & Photos
        .bolt, .photo, .cameraAperture, .fCursive,
        
        // Connectivity
        .network, .wifi, .dotRadiowavesUpForward, .antennaRadiowavesLeftAndRight, .chartBar,
        
        // Transport
        .figureWalk, .figureWave, .airplane, .bus, .tram, .cablecar, .ferry, .boxTruck, .bicycle, .scooter,
        
        // Automotive
        /*.engineCombustion,*/ .roadLanes,
        
        // Human
        .person, .person2, .personBust, .figureRoll, .figureAmericanFootball, .figureArchery, .figureAustralianFootball, .figureBadminton, .figureBaseball, .figureBasketball, .figureBowling, .figureBoxing, .figureClimbing, .figureCooldown, .figureCoreTraining, .figureCricket, .figureSkiingCrosscountry, .figureCrossTraining, .figureCurling, .figureDance, .figureDiscSports, .figureSkiingDownhill, .figureElliptical, .figureEquestrianSports, .figureFencing, .figureFishing, .figureFlexibility, .figureStrengthtrainingFunctional, .figureGolf, .figureGymnastics, .figureHandCycling, .figureHandball, .figureHighintensityIntervaltraining, .figureHiking, .figureHockey, .figureHunting, .figureIndoorCycle, .figureJumprope, .figureKickboxing, .figureLacrosse, .figureMartialArts, .figureMindAndBody, .figureMixedCardio, .figureOpenWaterSwim, .figureOutdoorCycle, .figurePickleball, .figurePilates, .play, .figurePoolSwim, .figureRacquetball, .figureRolling, .figureRower, .figureRugby, .figureSailing, .figureSkating, .figureSnowboarding, .figureSoccer, .figureSocialdance, .figureSoftball, .figureSquash, .figureStairStepper, .figureStairs, .figureStepTraining, .figureSurfing, .figureTableTennis, .figureTaichi, .tennisball, .figureTrackAndField, .figureStrengthtrainingTraditional, .figureVolleyball, .figureWaterFitness, .figureWaterpolo, .figureWrestling, .figureYoga, .lungs, .eye, .nose, .mustache, .mouth, .brainHeadProfile, .handRaised, .handThumbsup, .handThumbsdown,
        
        // Home
        .house, .windowAwning, .spigot, .pipeAndDrop, .popcorn,
        
        // Nature
        .globeEuropeAfrica, .hare, .tortoise, .lizard, .bird, .ant, .ladybug, .fish, .pawprint, .leaf, .atom,
        
        // Commerce
        .signature, .giftcard, .banknote, .dollarsign, .eurosign,
        
        // Maths
        .xSquareroot, .angle, .sum, .percent, .function
    ]
    
    var body: some View {
        VStack {
            Image(systemSymbol: icon)
                .font(.largeTitle)
                .frame(width: 100, height: 100)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            Text("Create a new folder")
                .font(.largeTitle.bold())
            
            Form {
                TextField("Name", text: $name, prompt: Text("Folder"))
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 15))]) {
                        ForEach(symbols, id: \.rawValue) { symbol in
                            Button {
                                icon = symbol
                            } label: {
                                Image(systemSymbol: symbol)
                                    .foregroundColor(icon == symbol ? .accentColor : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Spacer()
                
                Button("Cancel", role: .cancel, action: {
                    modalShown = false
                })
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)
                
                Button("Add", action: {
                    let folder = FeedFolderModel(context: context)
                    folder.name = name
                    folder.icon = icon.rawValue
                    modalShown = false
                    
                    // TODO: Error management.
                    try? context.save()
                })
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .tint(.accentColor)
                .disabled(self.name.isEmpty)
            }
        }
        .frame(minWidth: 600, maxHeight: 500)
        .padding()
    }
}

struct NewFolderView_Previews: PreviewProvider {
    static var previews: some View {
        NewFolderView(modalShown: .constant(true))
    }
}
