
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
