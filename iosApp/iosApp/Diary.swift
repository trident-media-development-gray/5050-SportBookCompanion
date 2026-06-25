import SwiftUI

// =====================================================================================
//  DiaryView — the log. filter chips + day-grouped rows + swipe delete + tap to edit.
// =====================================================================================
struct DiaryView: View {
    @EnvironmentObject var b: Brain
    @State private var filter: Int = -1     // -1 == all, else kind index
    @State private var editing: Sess? = nil

    // group the (filtered) sessions by day-key, newest first. all inline, no helpers.
    private var groups: [(key: Int, rows: [Sess])] {
        let pool = b.sorted.filter { filter == -1 || $0.kind == filter }
        var dict: [Int: [Sess]] = [:]
        for s in pool { dict[b.dayKey(s.t), default: []].append(s) }
        return dict.keys.sorted(by: >).map { (key: $0, rows: dict[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom) {
                    Head(title: "Training Diary", sub: "\(b.totalSess) sessions • \(b.totalMins) min total")
                    Spacer()
                }
                .padding(.top, 8)

                // filter rail
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(-1, "All", "square.grid.2x2.fill")
                        ForEach(0..<Brain.kinds.count, id: \.self) { i in
                            filterChip(i, Brain.kinds[i], Brain.kindIcon[i])
                        }
                    }
                }

                if groups.isEmpty {
                    Panel {
                        VStack(spacing: 10) {
                            Image("football").resizable().scaledToFit().frame(height: 80).opacity(0.7)
                            Text(filter == -1 ? "Your diary is empty." : "Nothing logged for \(Brain.kinds[filter]).")
                                .font(.system(size: 15, weight: .semibold)).foregroundColor(P.ash)
                            Text("Tap ➕ to log a session.").font(.system(size: 13)).foregroundColor(P.ashDim)
                        }.frame(maxWidth: .infinity)
                    }
                } else {
                    ForEach(groups, id: \.key) { g in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dayLabel(g.key)).font(.system(size: 13, weight: .heavy)).tracking(1)
                                .foregroundColor(P.orange2).padding(.leading, 4).padding(.top, 4)
                            ForEach(g.rows) { s in
                                SessRow(s: s)
                                    .onTapGesture { editing = s }
                                    .contextMenu {
                                        Button(role: .destructive) { b.remove(s) } label: { Label("Delete", systemImage: "trash") }
                                        Button { editing = s } label: { Label("Edit", systemImage: "pencil") }
                                    }
                            }
                        }
                    }
                }

                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $editing) { s in AddSessionView(editing: s) }
    }

    private func filterChip(_ i: Int, _ name: String, _ icon: String) -> some View {
        let on = filter == i
        return Button {
            Haptics.tap(); filter = i
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
                Text(name).font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(on ? .black : P.ash)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(on ? P.orange : P.panel))
            .overlay(Capsule().stroke(P.stroke, lineWidth: on ? 0 : 1))
        }
    }

    private func dayLabel(_ key: Int) -> String {
        let today = b.dayKey(Date().timeIntervalSince1970)
        if key == today { return "TODAY" }
        if key == today - 1 { return "YESTERDAY" }
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date(timeIntervalSince1970: Double(key) * 86400 + 43200)).uppercased()
    }
}

// =====================================================================================
//  AddSessionView — hand-built editor (no SwiftUI Form, themed controls everywhere)
// =====================================================================================
struct AddSessionView: View {
    @EnvironmentObject var b: Brain
    @Environment(\.dismiss) private var dismiss

    let editing: Sess?

    @State private var kind: Int
    @State private var mins: Double
    @State private var intensity: Int
    @State private var rpe: Double
    @State private var mood: Int
    @State private var note: String
    @State private var tagText: String
    @State private var when: Date
    @State private var capWarn = false
    @State private var capMsg = ""
    @State private var photoImg: UIImage?    // live image shown in the editor
    @State private var photoDirty = false    // did the user change the photo this session?

    init(editing: Sess?) {
        self.editing = editing
        _kind      = State(initialValue: editing?.kind ?? 2)
        _mins      = State(initialValue: Double(editing?.mins ?? 45))
        _intensity = State(initialValue: editing?.intensity ?? 3)
        _rpe       = State(initialValue: Double(editing?.rpe ?? 6))
        _mood      = State(initialValue: editing?.mood ?? 3)
        _note      = State(initialValue: editing?.note ?? "")
        _tagText   = State(initialValue: (editing?.tags ?? []).joined(separator: ", "))
        _when      = State(initialValue: Date(timeIntervalSince1970: editing?.t ?? Date().timeIntervalSince1970))
        _photoImg  = State(initialValue: ImageStore.load(editing?.photo))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBG()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {

                        // kind
                        block("TRAINING TYPE") {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(0..<Brain.kinds.count, id: \.self) { i in
                                    Button { Haptics.tap(); kind = i } label: {
                                        VStack(spacing: 6) {
                                            Image(systemName: Brain.kindIcon[i]).font(.system(size: 18, weight: .bold))
                                            Text(Brain.kinds[i]).font(.system(size: 11, weight: .semibold)).multilineTextAlignment(.center)
                                        }
                                        .foregroundColor(kind == i ? .black : P.ash)
                                        .frame(maxWidth: .infinity).frame(height: 70)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(kind == i ? Brain.kindTint[i] : P.panel))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.stroke, lineWidth: kind == i ? 0 : 1))
                                    }
                                }
                            }
                        }

                        // duration
                        block("DURATION — \(Int(mins)) min") {
                            VStack(spacing: 10) {
                                Slider(value: $mins, in: 5...180, step: 5).tint(P.orange)
                                HStack(spacing: 8) {
                                    ForEach([20, 30, 45, 60, 90], id: \.self) { p in
                                        Button("\(p)m") { mins = Double(p) }
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Int(mins) == p ? .black : P.ash)
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .background(Capsule().fill(Int(mins) == p ? P.orange : P.panel2))
                                    }
                                }
                            }
                        }

                        // intensity dots
                        block("INTENSITY") {
                            HStack(spacing: 10) {
                                ForEach(1...5, id: \.self) { i in
                                    Button { Haptics.tap(); intensity = i } label: {
                                        Image(systemName: i <= intensity ? "flame.fill" : "flame")
                                            .font(.system(size: 26))
                                            .foregroundColor(i <= intensity ? P.heat(Double(i) / 5) : P.ashDim)
                                    }
                                }
                                Spacer()
                                Text("\(intensity)/5").font(.system(size: 15, weight: .bold)).foregroundColor(P.ash)
                            }
                        }

                        // rpe
                        block("PERCEIVED EXERTION (RPE) — \(Int(rpe))") {
                            Slider(value: $rpe, in: 1...10, step: 1).tint(P.heat(rpe / 10))
                        }

                        // mood
                        block("HOW DID IT FEEL?") {
                            HStack {
                                ForEach(0..<Brain.moodFace.count, id: \.self) { i in
                                    Button { Haptics.tap(); mood = i } label: {
                                        VStack(spacing: 4) {
                                            Text(Brain.moodFace[i]).font(.system(size: 30)).grayscale(mood == i ? 0 : 0.9).opacity(mood == i ? 1 : 0.5)
                                            Text(Brain.moodWord[i]).font(.system(size: 10, weight: .semibold)).foregroundColor(mood == i ? P.orange : P.ashDim)
                                        }.frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }

                        // note
                        block("NOTES") {
                            ZStack(alignment: .topLeading) {
                                if note.isEmpty {
                                    Text("What went well? What to fix next time?").font(.system(size: 14)).foregroundColor(P.ashDim).padding(.top, 8).padding(.leading, 5)
                                }
                                TextEditor(text: $note)
                                    .scrollContentBackground(.hidden)
                                    .frame(height: 96).foregroundColor(.white).font(.system(size: 14))
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 12).fill(P.panel2))
                        }

                        // photo
                        block("PHOTO") {
                            PhotoPicker(hasImage: photoImg != nil,
                                        onPick: { photoImg = $0; photoDirty = true },
                                        onRemove: photoImg == nil ? nil : { photoImg = nil; photoDirty = true }) {
                                if let img = photoImg {
                                    Image(uiImage: img).resizable().scaledToFill()
                                        .frame(height: 160).frame(maxWidth: .infinity).clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(alignment: .topTrailing) {
                                            Image(systemName: "pencil.circle.fill").font(.system(size: 26))
                                                .foregroundStyle(.white, P.orange).padding(8)
                                        }
                                } else {
                                    VStack(spacing: 6) {
                                        Image(systemName: "camera.fill").font(.system(size: 22, weight: .bold)).foregroundColor(P.orange)
                                        Text("Add a photo").font(.system(size: 13, weight: .semibold)).foregroundColor(P.ash)
                                    }
                                    .frame(maxWidth: .infinity).frame(height: 90)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(P.panel2)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(P.stroke, style: StrokeStyle(lineWidth: 1, dash: [5]))))
                                }
                            }
                        }

                        // tags
                        block("TAGS (comma separated)") {
                            TextField("", text: $tagText, prompt: Text("routes, legs, pr").foregroundColor(P.ashDim))
                                .foregroundColor(.white).font(.system(size: 14))
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(P.panel2))
                                .autocorrectionDisabled()
                        }

                        // date
                        block("WHEN") {
                            DatePicker("", selection: $when, in: ...Date()).labelsHidden().datePickerStyle(.compact).tint(P.orange)
                        }

                        if editing != nil {
                            Button(role: .destructive) {
                                if let e = editing { b.remove(e) }; dismiss()
                            } label: {
                                Label("Delete session", systemImage: "trash")
                                    .font(.system(size: 15, weight: .bold)).foregroundColor(P.ember)
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(P.ember.opacity(0.12)))
                            }
                        }

                        Color.clear.frame(height: 20)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(editing == nil ? "Log Session" : "Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(P.ash)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.font(.system(size: 16, weight: .heavy)).foregroundColor(P.orange)
                }
            }
            .alert("That doesn't fit in a day", isPresented: $capWarn) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text(capMsg)
            }
        }
    }

    @ViewBuilder private func block<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 12, weight: .heavy)).tracking(1).foregroundColor(P.ash)
            c()
        }
    }

    private func save() {
        let tags = tagText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }

        // reality check: everything already logged on this calendar day (minus the row
        // we're editing) plus this one can't blow past 24h. blocks the "334h/week" nonsense.
        let already = b.minutesOnDay(of: when.timeIntervalSince1970, ignoring: editing?.id)
        if already + Int(mins) > Brain.DAY_CAP_MIN {
            let leftH = Double(max(0, Brain.DAY_CAP_MIN - already)) / 60
            capMsg = already >= Brain.DAY_CAP_MIN
                ? "You've already logged 24h of training on this day. There aren't any more hours to give."
                : "You've already logged \(String(format: "%.1f", Double(already) / 60))h that day — only \(String(format: "%.1f", leftH))h left before you hit 24h. Trim this session or pick another day."
            capWarn = true
            return
        }

        // resolve the photo: only touch disk if the user changed it this session
        var photoName = editing?.photo
        if photoDirty {
            ImageStore.delete(editing?.photo)                       // drop the old jpeg
            photoName = photoImg.flatMap { ImageStore.save($0) }    // save the new one (if any)
        }

        if var e = editing {
            e.kind = kind; e.mins = Int(mins); e.intensity = intensity; e.rpe = Int(rpe)
            e.mood = mood; e.note = note; e.tags = tags; e.t = when.timeIntervalSince1970
            e.photo = photoName
            b.update(e)
        } else {
            b.add(Sess(t: when.timeIntervalSince1970, kind: kind, mins: Int(mins),
                       intensity: intensity, rpe: Int(rpe), mood: mood, note: note,
                       drill: nil, tags: tags, photo: photoName))
        }
        dismiss()
    }
}
