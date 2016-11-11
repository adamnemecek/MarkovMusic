
import Cocoa
import AVFoundation

struct Song {
    
    var name:String
    var tempo:Float64
    var tracks:[Track]
    
}

struct Track {
    
    var name:String
    var notes:[Note]
    
    init(name: String, notes: [Note]) {
        
        self.name = name
        self.notes = notes
        
    }
    
    init(track: MusicTrack, named: String) {
        
        var iterator: MusicEventIterator?
        NewMusicEventIterator(track, &iterator)
        
        var hasNext: DarwinBoolean = false
        MusicEventIteratorHasCurrentEvent(iterator!, &hasNext)
        
        notes = []
        name = named
        
        while hasNext.boolValue {
            
            var timestamp: MusicTimeStamp = 0
            var eventType: MusicEventType = 0
            var eventData: UnsafeRawPointer? = nil
            var eventDataSize: UInt32 = 0
            
            MusicEventIteratorGetEventInfo(iterator!,
                                           &timestamp,
                                           &eventType,
                                           &eventData,
                                           &eventDataSize);
            
            if eventType == kMusicEventType_MIDINoteMessage {
                
                let message = eventData!.assumingMemoryBound(to: MIDINoteMessage.self)
                let note = Note(note: message[0].note, velocity: message[0].velocity, duration: message[0].duration)
                notes.append(note)
                
            }
            
            MusicEventIteratorNextEvent(iterator!)
            MusicEventIteratorHasCurrentEvent(iterator!, &hasNext)
            
        }
        
    }
    
    func musicTrack(channel: UInt8, sequence: MusicSequence) -> MusicTrack? {
        
        var timing: MusicTimeStamp = 0.0
        
        var musicTrack: MusicTrack? = nil
        
        let status = MusicSequenceNewTrack(sequence, &musicTrack)
        
        if status == OSStatus(noErr) && musicTrack != nil {
            for f in self.notes {
                
                var midiNote = MIDINoteMessage(channel: UInt8(channel), note: UInt8(f.note), velocity: UInt8(f.velocity), releaseVelocity: UInt8(0), duration: Float32(f.duration))
                
                let newNoteStatus = MusicTrackNewMIDINoteEvent(musicTrack!, timing, &midiNote)
                
                timing += MusicTimeStamp(f.duration)
                
                if newNoteStatus != OSStatus(noErr) {
                    
                    print("failed to make a note")
                    
                } else {
                    
                    print("Made a note \(f.note)")
                    
                }

            }
            
        }
        
        return musicTrack
        
    }
    
}

struct Note {
    
    var note:UInt8
    var velocity:UInt8
    var duration:Float32
    
}

struct MarkovNoteChain {
    
    var noteDict:Dictionary<UInt8, [UInt8]>
    var velocityDict:Dictionary<UInt8, [UInt8]>
    var durationDict:Dictionary<Float, [Float]>
    
    init(track: Track) {
        
        noteDict = [UInt8: [UInt8]]()
        velocityDict = [UInt8: [UInt8]]()
        durationDict = [Float: [Float]]()
        
        for f in track.notes {
            
            noteDict[f.note] = []
            velocityDict[f.velocity] = []
            durationDict[f.duration] = []
            
        }
        
        var noteArr: [UInt8] = []
        var velocityArr: [UInt8] = []
        var durationArr: [Float] = []
        
        for (note, _) in noteDict {
            
            for (noteIndex, noteItem) in track.notes.enumerated() {
                
                if note == noteItem.note && noteIndex < track.notes.count - 2 {
                    
                    noteArr.append(track.notes[noteIndex + 1].note)
                    
                }
                
            }
            
            noteDict[note] = noteArr
            noteArr.removeAll(keepingCapacity: true)
            
        }
        
        for (velocity, _) in velocityDict {
            
            for (velocityIndex, velocityItem) in track.notes.enumerated() {
                
                if velocity == velocityItem.velocity && velocityIndex < track.notes.count - 2 {
                    
                    velocityArr.append(track.notes[velocityIndex + 1].velocity)
                    
                }
                
            }
            
            velocityDict[velocity] = velocityArr
            velocityArr.removeAll(keepingCapacity: true)
            
        }
        
        for (duration, _) in durationDict {
            
            for (durationIndex, durationItem) in track.notes.enumerated() {
                
                if duration == durationItem.duration && durationIndex < track.notes.count - 2 {
                    
                    durationArr.append(track.notes[durationIndex + 1].duration)
                    
                }
                
            }
            
            durationDict[duration] = durationArr
            durationArr.removeAll(keepingCapacity: true)
            
        }
        
    }

    func nextNote(note: Note) -> Note {
        
        var noteNum: UInt8 = UInt8(arc4random_uniform(128))
        var velocityNum: UInt8 = UInt8(arc4random_uniform(128))
        var durationNum: Float = Float(arc4random_uniform(2))
        
        if let nextNotes = noteDict[note.note] {
            
            noteNum = nextNotes[Int(arc4random_uniform(UInt32(nextNotes.count)))]
            
        }
        
        if let nextVelocities = velocityDict[note.velocity] {
            
            velocityNum = nextVelocities[Int(arc4random_uniform(UInt32(nextVelocities.count)))]
            
        }
        
        if let nextDurations = durationDict[note.duration] {
            
            let ind = Int(arc4random_uniform(UInt32(nextDurations.count)))
            
            if nextDurations.count == 0 {
                
                print("For some reason nextDurations is empty, defaulting to duration = 1")
                durationNum = 1
                
            } else {
                
                durationNum = nextDurations[ind]
                
            }
        }
        
        return Note(note: noteNum, velocity: velocityNum, duration: durationNum)
        
    }
    
    func track(noteCount: Int, tempo: Float64, startNote: Note) -> Track {
        
        var notes: [Note] = []
        
        var playNote = startNote
        for _ in 0..<25 {
            
            playNote = nextNote(note: playNote)
            notes.append(playNote)
            
        }
        
        return Track(name: "A", notes: notes)
        
    }
    
}

func createSong(url: URL) -> Song? {
    
    var sequence: MusicSequence?
    let status = NewMusicSequence(&sequence)
    
    let name = url.lastPathComponent
    
    if status == OSStatus(noErr) {
        
        MusicSequenceFileLoad(sequence!, url as CFURL, MusicSequenceFileTypeID(rawValue: 0)!, .smf_ChannelsToTracks)
        var tempoTrack: MusicTrack?
        MusicSequenceGetTempoTrack(sequence!, &tempoTrack)
        
        let tempo = parseTempoTrack(track: tempoTrack!)
        
        var trackCount:UInt32 = 0
        MusicSequenceGetTrackCount(sequence!, &trackCount)

        var tracks: [Track] = []
        
        for i in 0..<trackCount {
            
            var trackData: MusicTrack?
            MusicSequenceGetIndTrack(sequence!, i, &trackData)
            
            let track = Track(track: trackData!, named: "\(i)")
            
            tracks.append(track)
            
        }
        
        let song: Song = Song(name: name, tempo: tempo!, tracks: tracks)
        
        return song
        
    } else {
        
        return nil
        
    }
    
}

func parseTempoTrack(track: MusicTrack) -> Float64? {
    
    var iterator: MusicEventIterator?
    NewMusicEventIterator(track, &iterator)
    
    var hasNext: DarwinBoolean = false
    MusicEventIteratorHasCurrentEvent(iterator!, &hasNext)
    
    while hasNext.boolValue {
        
        var timestamp: MusicTimeStamp = 0
        var eventType: MusicEventType = 0
        var eventData: UnsafeRawPointer? = nil
        var eventDataSize: UInt32 = 0
        
        MusicEventIteratorGetEventInfo(iterator!,
                                       &timestamp,
                                       &eventType,
                                       &eventData,
                                       &eventDataSize);
        
        if eventType == kMusicEventType_ExtendedTempo {
            
            let tempoData = eventData!.assumingMemoryBound(to: ExtendedTempoEvent.self)
            return tempoData[0].bpm
            
        }
        
        MusicEventIteratorNextEvent(iterator!)
        MusicEventIteratorHasCurrentEvent(iterator!, &hasNext)
        
    }
    
    return nil
}

func tempoTrack(channel: UInt8, sequence: MusicSequence) -> MusicTrack? {
    
    var tempoTrack: MusicTrack? = nil
    let status = MusicSequenceNewTrack(sequence, &tempoTrack)
    
    if status == OSStatus(noErr) && tempoTrack != nil {
        
        print("something happened")
        
//        var tempoEvent = ExtendedTempoEvent(bpm: 50)
        
        let tempoMidi = MusicTrackNewExtendedTempoEvent(tempoTrack!, 0, 50)
        
        print("something happened")
        
    }
    
    return tempoTrack
    
}


let path = Bundle.main.path(forResource: "d_bunny", ofType: "mid")!
let url = URL(fileURLWithPath: path)


if let song = createSong(url: url) {
    
    var sequence: MusicSequence?
    let status = NewMusicSequence(&sequence)
    
    let markovNoteChain = MarkovNoteChain(track: song.tracks[0])

    var playNote = song.tracks[0].notes[0]
//    for i in 0..<25 {
//        playNote = markovNoteChain.nextNote(note: playNote)
//    }
    
    let newTrack = markovNoteChain.track(noteCount: 25, tempo: 120, startNote: playNote)
    tempoTrack(channel: 0, sequence: sequence!)
    newTrack.musicTrack(channel: 1, sequence: sequence!)
    
    var trackCount:UInt32 = 0
    MusicSequenceGetTrackCount(sequence!, &trackCount)
    
    print(trackCount)
    
//    public func NewMusicPlayer(_ outPlayer: UnsafeMutablePointer<MusicPlayer?>) -> OSStatus
    
    var player: MusicPlayer?
    let playerStatus = NewMusicPlayer(&player)
    
    if playerStatus == OSStatus(noErr) && player != nil {
        MusicPlayerSetSequence(player!, sequence!)
        MusicPlayerStart(player!)
    }
    
} else {
    
    print("No song")
    
}

