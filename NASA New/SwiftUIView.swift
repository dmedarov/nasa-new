//import SwiftUI
//
////struct MainView: View, Sendable {
//    @EnvironmentObject var fetcher: NasaCollectionFetcher
//
//    @State private var memeText = ""
//    @State private var textSize = 60.0
//    @State private var textColor = Color.white
//
//    @FocusState private var isFocused: Bool
//
//    // MARK: - PROPERTY
//    @State private var isAnimating: Bool = false
//    @State private var imageScale: CGFloat = 1
//    @State private var imageOffset: CGSize = .zero
//    // @State private var isDrawerOpen: Bool = false
//    @State private var isZoom: Bool = false
//
//    // MARK: - FUNCTION
//    func resetImageState() {
//        return withAnimation(.spring()) {
//            isZoom = false
//            imageScale = 1
//            imageOffset = .zero
//        }
//    }
//
//    @AppStorage("isDarkMode") private var isDarkmode: Bool = false
//
//    var body: some View {
//        ZStack {
//            // MARK: - HEADER
//            HStack(alignment: .top, spacing: 10) {
////                // TITLE
////                Text("Complete")
////                    .font(.system(.largeTitle, design: .rounded))
////                    .fontWeight(.heavy)
////                    .padding(.leading, 4)
////                    .foregroundColor(isDarkmode ? Color(UIColor.white) : Color(UIColor.systemIndigo))
////                    .onAppear {
////                      //  AppReviewRequest.requestReviewIfNeeded()
////                    }
////                Spacer()
////
////                // EDIT BUTTON
////                EditButton()
////                    .font(.system(size: 16, weight: .semibold, design: .rounded))
////                    .padding(.horizontal, 10)
////                    .frame(minWidth: 70, minHeight: 24)
////                    .background(Capsule().stroke(isDarkmode ? Color(UIColor.white) : Color(UIColor.systemIndigo), lineWidth: 2))
////                    //                          .background(Capsule().stroke(Color.blue, lineWidth: 2))
////                    .foregroundColor(isDarkmode ? Color(UIColor.white) : Color(UIColor.systemIndigo))
////
//                // APPEARENCE BUTTON
//                Button(action: {
//                    isDarkmode.toggle()
////                    playSound(sound: "sound-tap", type: "mp3")
////                    feedback.notificationOccurred(.success)
////                    AnalyticsService.instance.darkModeChange()
//                }, label: {
//                    Image(systemName: isDarkmode ? "sun.min.fill" :  "moon.circle")
//                        .resizable()
//                        .frame(width: 24, height: 24)
//                        .font(.system(.title, design: .rounded))
//                        .foregroundColor(isDarkmode ? Color(UIColor.white) : Color(UIColor.systemIndigo))
//                })
//
//
//
//            } //: HSTACK
//            .padding()
//            //                    .foregroundColor(.white)
//            Spacer()
//            Spacer(minLength: 10)
//
////            VStack {
////                LoadableImage(imageMetadata: fetcher.currentNasa)
////                  //  .fixedSize(horizontal: false, vertical: false)
////                  //  .frame(width: 400, height: 400)
////
////                Text(fetcher.currentNasa.title)
////                    .font(.title2)
////                    .bold()
////                    .padding(2)
////
////
////                VStack{
////                    if let copyright = fetcher.currentNasa.copyright {
////                        Label(copyright, systemImage: "c.circle.fill")
////                            .symbolRenderingMode(.hierarchical)
////                    }
////                    Text(fetcher.currentNasa.date!)
////                        .font(.subheadline)
////                        .bold()
////
////                    ScrollView {
////                        Text(fetcher.currentNasa.explanation)
////                            .padding()
////                    }
////                    // .fixedSize(horizontal: false, vertical: true)
////
////                }
////                //            Spacer()
////
////                //            if !memeText.isEmpty {
////                //
////                //                VStack {
////                //                    HStack {
////                //                        Text("Font Size")
////                //                            .fontWeight(.semibold)
////                //                        Slider(value: $textSize, in: 20...140)
////                //                    }
////                //
////                //                    HStack {
////                //                        Text("Font Color")
////                //                            .fontWeight(.semibold)
////                //                        ColorPicker("Font Color", selection: $textColor)
////                //                            .labelsHidden()
////                //                            .frame(width: 124, height: 23, alignment: .leading)
////                //                        Spacer()
////                //                    }
////                //                }
////                //                .padding(.vertical)
////                //                .frame(maxWidth: 325)
////                //
////                //            }
////
//////                HStack (alignment: .top) {
//////
//////
//////                    Button {
//////                        if let randomImage = fetcher.imageData.randomElement() {
//////                            fetcher.currentNasa = randomImage
//////                        }
//////                    } label: {
//////                        VStack  {
//////                            //                        Image(systemName: "photo.on.rectangle.angled")
//////                            //                            .font(.title)
//////                            //                            .padding(.bottom, 2)
//////                            Text("Shuffle Photo")
//////                        }
//////                        .frame(maxWidth: 130, maxHeight: .infinity) //.infinity
//////                    }
//////                    .buttonStyle(.bordered)
//////                    .controlSize(.large)
//////
//////                    //                Spacer()
//////
//////                    //                Button {
//////                    //                    isFocused = true
//////                    //                } label: {
//////                    //                    VStack {
//////                    //                        Image(systemName: "textformat")
//////                    //                            .font(.largeTitle)
//////                    //                            .padding(.bottom, 4)
//////                    //                        Text("Add Text")
//////                    //                    }
//////                    //                    .frame(maxWidth: 180, maxHeight: .infinity)
//////                    //                }
//////                    //                .buttonStyle(.bordered)
//////                    //                .controlSize(.large)
////////                }
//////                .fixedSize(horizontal: false, vertical: true)
//////                .frame(maxHeight: 180, alignment: .center)
//////           }
////            // .padding()
////            .preferredColorScheme(.dark)
////            .task {
////                try? await fetcher.fetchData()
////            }
//        }
//        .navigationTitle("NASA")
//        .navigationBarTitleDisplayMode(.inline)
//        .onAppear(perform: {
//            withAnimation(.linear(duration: 1)) {
//                isAnimating = true
//            }
//        })
//    }
//}
//
