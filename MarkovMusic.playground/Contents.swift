
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
    
}

struct Note {
    
    var note:UInt8
    var velocity:UInt8
    var duration:Float
    
}

struct MarkovNote {
    
    var noteDict:Dictionary<UInt8, [UInt8]>
    var velocityDict:Dictionary<UInt8, [UInt8]>
    var durationDict:Dictionary<Float, [Float]>
    
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
            
            let track = Track(name: "\(i)", notes: parseTrack(track: trackData!))
            
            tracks.append(track)
            
        }
        
        let song: Song = Song(name: name, tempo: tempo!, tracks: tracks)
        
        return song
        
    } else {
        
        return nil
        
    }
    
}

func parseTrack(track: MusicTrack) -> [Note] {
    
    var iterator: MusicEventIterator?
    NewMusicEventIterator(track, &iterator)
    
    var hasNext: DarwinBoolean = false
    MusicEventIteratorHasCurrentEvent(iterator!, &hasNext)
    
    var returnArray: [Note] = []
    
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
            let note: Note = Note(note: message[0].note, velocity: message[0].velocity, duration: message[0].duration)
            returnArray.append(note)
            
        }
        
        MusicEventIteratorNextEvent(iterator!)
        MusicEventIteratorHasCurrentEvent(iterator!, &hasNext)
        
    }
    
    return returnArray
    
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
            
        } else {
            
            return nil
        }
        
        MusicEventIteratorNextEvent(iterator!)
        MusicEventIteratorHasCurrentEvent(iterator!, &hasNext)
        
    }
    
    return nil
}

func createMarkovNote(track: Track) -> MarkovNote {
    
    var noteDict = [UInt8: [UInt8]]()
    var velocityDict = [UInt8: [UInt8]]()
    var durationDict = [Float: [Float]]()
    
    for f in track.notes {
        noteDict[f.note] = []
        velocityDict[f.velocity] = []
        durationDict[f.duration] = []
    }
    
    var noteArr: [UInt8] = []
    var velocityArr: [UInt8] = []
    var durationArr: [Float] = []
    
    for (index, item) in noteDict.enumerated() {
        for (noteIndex, noteItem) in track.notes.enumerated() {
            if item.key == noteItem.note && noteIndex < track.notes.count - 1 {
                noteArr.append(track.notes[noteIndex + 1].note)
            }
        }
        
        noteDict[item.key] = noteArr
        noteArr = []
        
    }
    
    for (index, item) in velocityDict.enumerated() {
        for (velocityIndex, velocityItem) in track.notes.enumerated() {
            if item.key == velocityItem.velocity && velocityIndex < track.notes.count - 1 {
                velocityArr.append(track.notes[velocityIndex + 1].velocity)
            }
        }
        
        velocityDict[item.key] = velocityArr
        velocityArr = []
        
    }
    
    for (index, item) in durationDict.enumerated() {
        for (durationIndex, durationItem) in track.notes.enumerated() {
            if item.key == durationItem.duration && durationIndex < track.notes.count - 1 {
                durationArr.append(track.notes[durationIndex + 1].duration)
            }
        }
        
        durationDict[item.key] = durationArr
        durationArr = []
        
    }
    
    let returnMarkov = MarkovNote(noteDict: noteDict, velocityDict: velocityDict, durationDict: durationDict)
    
    return returnMarkov
    
}

func nextNote(markov: MarkovNote, note: Note) -> Note {
    
    var noteNum: UInt8 = UInt8(arc4random_uniform(128))
    var velocityNum: UInt8 = UInt8(arc4random_uniform(128))
    var durationNum: Float = Float(arc4random_uniform(2))
    
    for f in markov.noteDict {
        
        if f.key == note.note {
            
            let randomIndex = Int(arc4random_uniform(UInt32(f.value.count)))
            noteNum = f.value[randomIndex]
            
        }
        
    }
    
    for f in markov.velocityDict {
        
        if f.key == note.velocity {
            
            let randomIndex = Int(arc4random_uniform(UInt32(f.value.count)))
            velocityNum = f.value[randomIndex]
            
        }
        
    }
    
    for f in markov.durationDict {
        
        if f.key == note.duration {
            
            let randomIndex = Int(arc4random_uniform(UInt32(f.value.count)))
            durationNum = f.value[randomIndex]
            
        }
        
    }
    
    let returnNote: Note = Note(note: noteNum, velocity: velocityNum, duration: durationNum)
    
    print(returnNote)
    
    return returnNote
    
}

let path = Bundle.main.path(forResource: "d_bunny", ofType: "mid")!
let url = URL(fileURLWithPath: path)

if let song = createSong(url: url) {
    
    for f in song.tracks {
        
        for g in f.notes {
            
            let markovNoteChain = createMarkovNote(track: f)
            nextNote(markov: markovNoteChain, note: g)
            
        }
        
    }
    
} else {
    
    print("No song")
    
}
