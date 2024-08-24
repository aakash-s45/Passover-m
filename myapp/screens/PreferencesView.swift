//
//  PreferencesView.swift
//  myapp
//
//  Created by Aakash Solanki on 12/05/24.
//

import Foundation
import SwiftUI
import CoreBluetooth
import IOBluetooth


struct NewWindow: View {
    @EnvironmentObject var bluetoothViewModel:BluetoothViewModel
    
    var body: some View {
        let currentDevice = bluetoothViewModel.currentDevice
        var connected = true
        VStack{
            if currentDevice != nil{
                if(!(currentDevice?.isConnected() ?? false)){
                    CurrentDevice(device: currentDevice!, rssi: -100).onAppear(perform: {connected = false})
                }
                else{
                    CurrentDevice(device: currentDevice!, rssi: 0).onAppear(perform: {connected = true})
                }
                
                HStack{
                    if connected{
                        Button("Disconnect device", action: {
                            bluetoothViewModel.disconnect()
                        })
                    }
                    else{
                        Button("Connect device", action: {
//                            bleViewModel.connectToDevice(peripheral: currentBleDevice!)
                            connected = true
                        })
                    }

                    Button("Remove current device", action: {
                        bluetoothViewModel.disconnect()
                        bluetoothViewModel.clearIdentifiers()
                    })
                }
            }
            else if !bluetoothViewModel.isScanning{
                Button("Start Scan", action: {
                    bluetoothViewModel.disconnect()
                })
            }
            else if bluetoothViewModel.isScanning{
                ScanResults()
            }
            Spacer(minLength: 10)
            
        }
    }
}




struct InquiryPane:View {
    @EnvironmentObject var bluetoothViewModel:BluetoothViewModel
    var body: some View {
        VStack{
            Text("Scan Results")
                    List(bluetoothViewModel.scanResults.sorted(by: { $0.value.intValue < $1.value.intValue }), id: \.key) { pair in
                                let device = pair.key
                                let value = pair.value
                        Text("\(device.nameOrAddress): \(value)")
            }
        }
    }
}



struct DeviceControlPane: View {
    @EnvironmentObject var bluetoothViewModel:BluetoothViewModel
    
    
    
    var body: some View {
        let scale = bluetoothViewModel.scale
//        InquiryPane()
//            .frame(width: 2*scale, height: 3*scale)
//            .background(VisualEffectView().ignoresSafeArea())

//        let currentDevice = bluetoothViewModel.currentDevice
//        var connected = true
        HStack{
//            device info (read)
            VStack{
                StatusBar().frame(width: 2*scale, height: 0.5*scale)
                DeviceImage().frame(width: 2*scale, height: 2*scale)
                MediaButtons()
                    .frame(width: 2*scale, height: 0.5*scale)
                    
                
            }
//            .background(Color(white: 0.3, opacity: 0.9))
            .frame(width: 2*scale, height: 3*scale)

            
//            device control dialpad
            VStack(alignment: .trailing){
                ZStack(alignment: .bottomLeading){
                    PhoneView().frame(width: 2*scale, height: 2*scale)
                    PhoneNavBar(scale: scale).offset(y: 80)
                }.frame(width: 3*scale, height: 3*scale)
            }
            .background(.ultraThickMaterial)
            
//            .background(.ultraThickMaterial)
    
        }.frame(width: 5*scale, height: 3*scale)
    }
}




struct DeviceImage:View {
    var body: some View {
        Text("Device view")
    }
}


struct StatusBar:View {
    let hfstate = HFDState.shared
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 20){
//            Notification count
//            Battery
//            signal strength
//            Image(systemName: "app.badge")
//            Text("42%")
            Image(systemName: hfstate.batteryText).onAppear(perform:{
                print("asdfgasdg: \(hfstate.batteryText)")
            })
            Image(systemName: "cellularbars")
        }.frame(alignment: .centerLastTextBaseline)
    }
}

struct MediaButtons:View {
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 15){
            Image(systemName: "backward.fill")
            Image(systemName: "play.fill")
            Image(systemName: "forward.fill")
        }
    }
}

struct PhoneNavBar:View {
    let scale:CGFloat
    var body: some View {
        let color = Color(white: 0.3)
        HStack(spacing: 20){
            Image(systemName: "phone.fill").imageScale(.large)
            Image(systemName: "person.crop.circle.fill").imageScale(.large)
            Image(systemName: "teletype").imageScale(.large)
        }
        .padding(20)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke( color,lineWidth: 1)
        )
        .frame(width: 2*scale, height: 1*scale)
    }
}

struct PhoneView:View {
    var body: some View {
        DialPad()
    }
}

struct Divider:View {
    let height: CGFloat
    let width: CGFloat
    let color: Color
    var body: some View {
        Rectangle()
            .frame(width: width, height: height)
            .foregroundColor(color)
    }
}



struct DialPad:View {
    @State private var dailNumber: String = ""
    var body: some View {
        VStack {
                TextField(
                    "Dial Number",
                    text: $dailNumber
                )
                .disableAutocorrection(true)
                .padding(20)
                .textFieldStyle(.roundedBorder)
                if( dailNumber.isEmpty){
                    Image(systemName: "xmark.circle").imageScale(.large).font(.system(size: 20))

                }
                else{
                    Image(systemName: "phone.circle.fill").imageScale(.large).font(.system(size: 20))
                }
            }

    }
}



func getBatteryString(charge: Int)->String{
    switch charge{
    case 0: return "battery.0percent"
    case 1: return "battery.25percent"
    case 2: return "battery.25percent"
    case 3: return "battery.50percent"
    case 4: return "battery.75percent"
    case 5: return "battery.100percent"
    default: return "battery.100percent"
    }
}






struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.state = .active
        return effectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    }
}


struct CallAlert:View {
    @EnvironmentObject var hfdState:HFDState
    var body: some View {
        let title = hfdState.callMapping["number"]!

        VStack{
            HStack(alignment: .center){
                Image(systemName: getImage(title: title)).imageScale(.large).font(.system(size: 30))
                VStack(alignment: .leading){
                    Text(title)
                    Text("from \(hfdState.devicename)").foregroundColor(.gray)
                }
                Spacer().frame(width:50)
                VStack(alignment: .leading){
                    Button("Accept", action: {
                        HFDState.shared.handsFreeDevice?.acceptCall()
                    })
                    Button("Reject", action: {
                        HFDState.shared.handsFreeDevice?.endCall()
                    })
                }
                
            }
            Spacer().frame(height:28)
        }
        .frame(width: 300, height: 70)
    }
}

struct ActiveCallPopUp:View {
    @EnvironmentObject var hfdState:HFDState
    var body: some View {
        let title = hfdState.callMapping["number"]!
        let status = hfdState.callMapping["status"]!
        let mode = hfdState.callMapping["mode"]!
        let timer = hfdState.elapsedTimeString
        VStack{
            HStack(alignment: .center){
                Image(systemName: getImage(title: title)).imageScale(.large).font(.system(size: 30))
                VStack(alignment: .leading){
                    Text(title)
                    if status == "talking"{
                        Text(timer).foregroundColor(.gray)
                    }
                    else{
                        Text(status).foregroundColor(.gray)
                    }
                }
                Spacer().frame(width:50)
                HStack(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, spacing: 0){
                    if mode == "in"{
                        Image(systemName: "arrow.down.backward").font(.system(size: 15))
                            .foregroundStyle(.green)
                    }
                    else{
                        Image(systemName: "arrow.up.right").font(.system(size: 15)).foregroundStyle(.blue)
                    }
    //                Image(systemName: "ellipsis.circle.fill").font(.system(size: 20))
                    
                    SignalStrength(active: hfdState.signal, scale: 3)
                    Image(systemName: getBatteryString(charge: self.hfdState.battery))
                }
//                Image(systemName: "ellipsis.circle.fill").font(.system(size: 20))
                Image(systemName: "phone.down.circle.fill").font(.system(size: 20)).foregroundStyle(.red).onTapGesture {
                    HFDState.shared.handsFreeDevice?.endCall()
                }
                
            }
            Spacer().frame(height:28)
        }
        .frame(width: 300, height: 70)
    }
}


func getImage(title: String) -> String {
//    guard let firstChar = title.first?.lowercased() else {
//        return "person.circle.fill" // Fallback in case title is empty
//    }
    
    return "person.circle.fill"
//    return "\(firstChar).circle.fill"
}

struct SignalStrength:View {
    var active:Int = 2
    var scale: CGFloat = 50
    let width: CGFloat = 1
    let height: CGFloat = 1
    let cornerRadius: CGFloat = 0.4
    var body: some View {
        HStack(alignment: .bottom, spacing: 0.2*scale){
            ForEach(0..<5) { number in
                if(number<=active){
                    RoundedRectangle(cornerRadius: cornerRadius*scale)
                        .frame(width: scale*width, height: scale*height*CGFloat(number))
                    .foregroundColor(.white)
                }
                else{
                    RoundedRectangle(cornerRadius: cornerRadius*scale)
                        .frame(width: scale*width, height: scale*height*CGFloat(number))
                        .foregroundColor(Color(white: 0.3))
                }

            }
        }.padding(10)
    }
}


#Preview{
    ActiveCallPopUp().environmentObject(HFDState.shared)
}

