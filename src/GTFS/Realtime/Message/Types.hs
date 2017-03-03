
module GTFS.Realtime.Message.Types (ForFeedElement(..), departureTimeWithDelay) where

import           Com.Google.Transit.Realtime.TripDescriptor                                 (TripDescriptor (..), trip_id)
import qualified Com.Google.Transit.Realtime.TripDescriptor.ScheduleRelationship            as TripSR
import Com.Google.Transit.Realtime.TripUpdate (TripUpdate(..))
import qualified Com.Google.Transit.Realtime.TripUpdate.StopTimeEvent (delay)
import qualified Com.Google.Transit.Realtime.TripUpdate.StopTimeUpdate                      as STU
import qualified Com.Google.Transit.Realtime.TripUpdate.StopTimeUpdate.ScheduleRelationship as StopTUSR
import qualified Com.Google.Transit.Realtime.VehiclePosition                                as VP
import qualified Com.Google.Transit.Realtime.VehiclePosition.CongestionLevel                as CL
import qualified Com.Google.Transit.Realtime.VehiclePosition.OccupancyStatus                as O
import           Data.Foldable                                                              (find)
import           Data.Time.Clock                                                            (secondsToDiffTime)
import           Data.Time.LocalTime                                                        (TimeOfDay, timeToTimeOfDay)
import           GTFS.Schedule                                                              (ScheduleItem (..), ScheduleState (..), Stop (..), VehicleInformation (..), secondsToDeparture)
import           Text.ProtocolBuffers.Basic                                                 (uToString)
import qualified Text.ProtocolBuffers.Header                                                as P'

class ForFeedElement e where
  getTripID :: e -> String
  getTripID x = uToString $ P'.getVal (getTripDescriptor x) trip_id

  getTripDescriptor :: e -> TripDescriptor
  updateScheduleItem :: e -> String -> ScheduleItem -> Maybe ScheduleItem


instance ForFeedElement TripUpdate where
    getTripDescriptor x = P'.getVal x trip
    updateScheduleItem TripUpdate{trip = TripDescriptor{schedule_relationship = Just TripSR.CANCELED}} k item =
        Just
            ScheduleItem
            { tripId = k
            , stop = stop item
            , serviceName = serviceName item
            , scheduledDepartureTime = scheduledDepartureTime item
            , departureDelay = 0
            , departureTime = departureTime item
            , scheduleType = CANCELED
            , scheduleItemVehicleInformation = scheduleItemVehicleInformation item
            }
    updateScheduleItem tu k item = do
        stu <- findStopTimeUpdate (stop item) (getStopTimeUpdates tu)
        Just
            ScheduleItem
            { tripId = k
            , stop = stop item
            , serviceName = serviceName item
            , scheduledDepartureTime = scheduledDepartureTime item
            , departureDelay = getDepartureDelay stu
            , departureTime = departureTimeWithDelay
                  (scheduledDepartureTime item)
                  (getDepartureDelay stu)
            , scheduleType = scheduleTypeForStop stu
            , scheduleItemVehicleInformation = scheduleItemVehicleInformation item
            }

instance ForFeedElement VP.VehiclePosition where
  getTripDescriptor x = P'.getVal x VP.trip
  updateScheduleItem vp k item = Just ScheduleItem
            { tripId = k
            , stop = stop item
            , serviceName = serviceName item
            , scheduledDepartureTime = scheduledDepartureTime item
            , departureDelay = departureDelay item
            , departureTime = departureTime item
            , scheduleType = scheduleType item
            , scheduleItemVehicleInformation = makeVehicleInformation vp
            }

makeVehicleInformation ::
  VP.VehiclePosition
  -> VehicleInformation
makeVehicleInformation vp = let congestionl = fromEnum (P'.getVal vp VP.congestion_level)
                                c_percentage = (congestionl * 100) `div` fromEnum (maxBound :: CL.CongestionLevel)
                                occupancys = fromEnum (P'.getVal vp VP.occupancy_status)
                                o_percentage = (occupancys * 100) `div` fromEnum (maxBound :: O.OccupancyStatus)
                            in VehicleInformation (Just c_percentage) (Just o_percentage)


getDepartureDelay ::
  STU.StopTimeUpdate
  -> Integer
getDepartureDelay update = fromIntegral $ P'.getVal d Com.Google.Transit.Realtime.TripUpdate.StopTimeEvent.delay
  where d = P'.getVal update STU.departure

scheduleTypeForStop ::
  STU.StopTimeUpdate
  -> ScheduleState
scheduleTypeForStop STU.StopTimeUpdate { STU.schedule_relationship = Just StopTUSR.SKIPPED } = CANCELED
scheduleTypeForStop _ = SCHEDULED

-- | calculate the new departure time with a delay from the real time update
departureTimeWithDelay ::
  TimeOfDay
  -> Integer
  -> TimeOfDay
departureTimeWithDelay depTime d = timeToTimeOfDay $ secondsToDeparture depTime (secondsToDiffTime d)

getStopTimeUpdates ::
  TripUpdate
  -> P'.Seq STU.StopTimeUpdate
getStopTimeUpdates msg = P'.getVal msg stop_time_update

findStopTimeUpdate ::
  Stop
  -> P'.Seq STU.StopTimeUpdate
  -> Maybe STU.StopTimeUpdate
findStopTimeUpdate s = find (\x -> stopTimeUpdateStopID x == stopIdentifier s)

stopTimeUpdateStopID ::
  STU.StopTimeUpdate
  -> String
stopTimeUpdateStopID msg = uToString $ P'.getVal msg STU.stop_id