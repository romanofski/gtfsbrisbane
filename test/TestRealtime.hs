{-
Copyright (C) - 2017 Róman Joost <roman@bromeco.de>

This file is part of gtfsschedule.

gtfsschedule is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

gtfsschedule is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with gtfsschedule.  If not, see <http://www.gnu.org/licenses/>.
-}
module TestRealtime (feedTests) where

import Fixtures

import GTFS.Realtime.Message.Schedule (updateSchedule)
import GTFS.Realtime.Message.Types (departureTimeWithDelay)
import GTFS.Realtime.Internal.Com.Google.Transit.Realtime.FeedMessage
       (FeedMessage)
import GTFS.Schedule

import qualified GTFS.Realtime.Internal.Com.Google.Transit.Realtime.TripDescriptor.ScheduleRelationship as TUSR
import qualified GTFS.Realtime.Internal.Com.Google.Transit.Realtime.TripUpdate.StopTimeUpdate.ScheduleRelationship as STUSR
import qualified GTFS.Realtime.Internal.Com.Google.Transit.Realtime.VehiclePosition.CongestionLevel as VPCL
import qualified GTFS.Realtime.Internal.Com.Google.Transit.Realtime.VehiclePosition.OccupancyStatus as VPOS

import Data.Functor ((<$>))

import Test.Tasty (TestTree, TestName, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Data.Time.LocalTime (TimeOfDay(..))

import qualified Data.Sequence as Seq


feedTests ::
  TestTree
feedTests = testGroup "realtime feed Tests"
            [ testDepartureWithDelay
            , testWithRealtimeFeed
            ]


makeFeedTest :: (TestName, FeedMessage, [ScheduleItem], [ScheduleItem])
             -> TestTree
makeFeedTest (name,fm,schedule,expected) =
    testCase name $ do updateSchedule fm schedule @?= expected

makeFeedWithVehiclePosition :: FeedMessage
makeFeedWithVehiclePosition =
    let vp =
            Just $
            testVehiclePosition
                (Just "600202")
                (Just VPCL.SEVERE_CONGESTION)
                (Just VPOS.NOT_ACCEPTING_PASSENGERS)
                (Just "trip congested and full")
                (Just TUSR.SCHEDULED)
        vp' =
            Just $
            testVehiclePosition
                (Just "603333")
                Nothing
                Nothing
                (Just "trip congested and full")
                (Just TUSR.SCHEDULED)
        tuCanceled =
            Just $
            testTripUpdate
                (Just "trip congested and full")
                (Just TUSR.CANCELED)
                (Seq.empty)
    in testFeedMessage $
       Seq.fromList [testFeedEntity tuCanceled vp, testFeedEntity Nothing vp']

makeFeedWithCanceledTrips :: FeedMessage
makeFeedWithCanceledTrips =
    let tuCanceled =
            Just $
            testTripUpdate
                (Just "7634889-SUN 16_17-SUN_SUN-Sunday-01")
                (Just TUSR.CANCELED)
                (Seq.empty)
        tuSkipped =
            Just $
            testTripUpdate
                (Just "trip with skipped stop")
                (Just TUSR.SCHEDULED)
                (Seq.fromList
                     [ testStopTimeUpdate
                           (Just "600202")
                           Nothing
                           (Just STUSR.SKIPPED)])
    in testFeedMessage $
       Seq.fromList
           [testFeedEntity tuCanceled Nothing, testFeedEntity tuSkipped Nothing]

makeFeedWithTripDelays :: FeedMessage
makeFeedWithTripDelays =
    let tuDelayed1 =
            Just $
            testTripUpdate
                (Just "7935244-SBL 16_17-SBL_SUN-Sunday-01")
                Nothing
                (Seq.fromList
                     [ testStopTimeUpdate
                           (Just "301350")
                           (Just $
                            testStopTimeEvent
                                (Just 155)
                                (Just $ TimeOfDay 10 32 35))
                           Nothing])
        tuDelayed2 =
            Just $
            testTripUpdate
                (Just "7822824-BT 16_17-JUL_FUL-Sunday-02")
                (Just TUSR.SCHEDULED)
                (Seq.fromList
                     [ testStopTimeUpdate
                           (Just "11168")
                           (Just $
                            testStopTimeEvent
                                (Just $ 66)
                                (Just $ TimeOfDay 8 1 6))
                           Nothing])
        tuCanceled =
            Just $
            testTripUpdate
                (Just "7634889-SUN 16_17-SUN_SUN-Sunday-01")
                (Just TUSR.CANCELED)
                (Seq.empty)
    in testFeedMessage $
       Seq.fromList
           [ testFeedEntity Nothing Nothing
           , testFeedEntity tuDelayed1 Nothing
           , testFeedEntity tuDelayed2 Nothing
           , testFeedEntity tuCanceled Nothing]


testWithRealtimeFeed ::
  TestTree
testWithRealtimeFeed =
    testGroup "with realtime feed" $
    makeFeedTest <$>
    [ ( "full updates"
      , makeFeedWithTripDelays
      , [ ScheduleItem
          { tripId = "7935244-SBL 16_17-SBL_SUN-Sunday-01"
          , stop = Stop
            { stopIdentifier = "301350"
            , stopWalktime = 0
            , stopName = ""
            }
          , serviceName = "S2"
          , scheduledDepartureTime = TimeOfDay 10 30 0
          , departureDelay = 0
          , departureTime = TimeOfDay 10 30 0
          , scheduleType = SCHEDULED
          , scheduleItemVehicleInformation = VehicleInformation Nothing Nothing
          }
        , ScheduleItem
          { tripId = "7822824-BT 16_17-JUL_FUL-Sunday-02"
          , stop = Stop
            { stopIdentifier = "11168"
            , stopWalktime = 0
            , stopName = ""
            }
          , serviceName = "S1"
          , scheduledDepartureTime = TimeOfDay 8 0 0
          , departureDelay = 0
          , departureTime = TimeOfDay 8 0 0
          , scheduleType = SCHEDULED
          , scheduleItemVehicleInformation = VehicleInformation Nothing Nothing
          }]
      , [ ScheduleItem
          { tripId = "7822824-BT 16_17-JUL_FUL-Sunday-02"
          , stop = Stop
            { stopIdentifier = "11168"
            , stopWalktime = 0
            , stopName = ""
            }
          , serviceName = "S1"
          , scheduledDepartureTime = TimeOfDay 8 0 0
          , departureDelay = 66
          , departureTime = TimeOfDay 8 1 6
          , scheduleType = SCHEDULED
          , scheduleItemVehicleInformation = VehicleInformation Nothing Nothing
          }
        , ScheduleItem
          { tripId = "7935244-SBL 16_17-SBL_SUN-Sunday-01"
          , stop = Stop
            { stopIdentifier = "301350"
            , stopWalktime = 0
            , stopName = ""
            }
          , serviceName = "S2"
          , scheduledDepartureTime = TimeOfDay 10 30 0
          , departureDelay = 155
          , departureTime = TimeOfDay 10 32 35
          , scheduleType = SCHEDULED
          , scheduleItemVehicleInformation = VehicleInformation Nothing Nothing
          }])
    , ( "no updates"
      , makeFeedWithTripDelays
      , [ ScheduleItem
          { tripId = "has no realtime update"
          , stop = Stop
            { stopIdentifier = "232323"
            , stopWalktime = 0
            , stopName = ""
            }
          , serviceName = "S2"
          , scheduledDepartureTime = TimeOfDay 8 0 0
          , departureDelay = 0
          , departureTime = TimeOfDay 8 0 0
          , scheduleType = SCHEDULED
          , scheduleItemVehicleInformation = VehicleInformation Nothing Nothing
          }]
      , [ ScheduleItem
          { tripId = "has no realtime update"
          , stop = Stop
            { stopIdentifier = "232323"
            , stopWalktime = 0
            , stopName = ""
            }
          , serviceName = "S2"
          , scheduledDepartureTime = TimeOfDay 8 0 0
          , departureDelay = 0
          , departureTime = TimeOfDay 8 0 0
          , scheduleType = SCHEDULED
          , scheduleItemVehicleInformation = VehicleInformation Nothing Nothing
          }])
    , ( "partial update"
      , makeFeedWithTripDelays
      , [ ScheduleItem
          { tripId = "7935244-SBL 16_17-SBL_SUN-Sunday-01"
          , stop = Stop
            { stopIdentifier = "301350"
            , stopWalktime = 0
            , stopName = ""
            }
          , serviceName = "S2"
          , scheduledDepartureTime = TimeOfDay 10 30 0
          , departureDelay = 0
          , departureTime = TimeOfDay 10 30 0
          , scheduleType = SCHEDULED
          , scheduleItemVehicleInformation = VehicleInformation Nothing Nothing
          }
        , ScheduleItem
          { tripId = "no realtime update"
          , stop = Stop
            { stopIdentifier = "0815"
            , stopWalktime = 0
            , stopName = ""
            }
          , serviceName = "S1"
          , scheduledDepartureTime = TimeOfDay 8 0 0
          , departureDelay = 0
          , departureTime = TimeOfDay 8 0 0
          , scheduleType = SCHEDULED
          , scheduleItemVehicleInformation = VehicleInformation Nothing Nothing
          }]
      , [ ScheduleItem
          { tripId = "7935244-SBL 16_17-SBL_SUN-Sunday-01"
          , stop = Stop
            { stopIdentifier = "301350"
            , stopWalktime = 0
            , stopName = ""
            }
          , serviceName = "S2"
          , scheduledDepartureTime = TimeOfDay 10 30 0
          , departureDelay = 155
          , departureTime = TimeOfDay 10 32 35
          , scheduleType = SCHEDULED
          , scheduleItemVehicleInformation = VehicleInformation Nothing Nothing
          }
        , ScheduleItem
          { tripId = "no realtime update"
          , stop = Stop
            { stopIdentifier = "0815"
            , stopWalktime = 0
            , stopName = ""
            }
          , serviceName = "S1"
          , scheduledDepartureTime = TimeOfDay 8 0 0
          , departureDelay = 0
          , departureTime = TimeOfDay 8 0 0
          , scheduleType = SCHEDULED
          , scheduleItemVehicleInformation = VehicleInformation Nothing Nothing
          }])
    , ( "canceled service"
      , makeFeedWithCanceledTrips
      , [ ScheduleItem
          { tripId = "7634889-SUN 16_17-SUN_SUN-Sunday-01"
          , stop = Stop
            { stopIdentifier = "317579"
            , stopWalktime = 0
            , stopName = ""
            }
          , serviceName = "S2"
          , scheduledDepartureTime = TimeOfDay 10 30 0
          , departureDelay = 0
          , departureTime = TimeOfDay 10 30 0
          , scheduleType = SCHEDULED
          , scheduleItemVehicleInformation = VehicleInformation Nothing Nothing
          }]
      , [ ScheduleItem
          { tripId = "7634889-SUN 16_17-SUN_SUN-Sunday-01"
          , stop = Stop
            { stopIdentifier = "317579"
            , stopWalktime = 0
            , stopName = ""
            }
          , serviceName = "S2"
          , scheduledDepartureTime = TimeOfDay 10 30 0
          , departureDelay = 0
          , departureTime = TimeOfDay 10 30 0
          , scheduleType = CANCELED
          , scheduleItemVehicleInformation = VehicleInformation Nothing Nothing
          }])
    , ( "skipped stop"
      , makeFeedWithCanceledTrips
      , [ ScheduleItem
          { tripId = "trip with skipped stop"
          , stop = Stop
            { stopIdentifier = "600202"
            , stopWalktime = 0
            , stopName = ""
            }
          , serviceName = "S2"
          , scheduledDepartureTime = TimeOfDay 10 30 0
          , departureDelay = 0
          , departureTime = TimeOfDay 10 30 0
          , scheduleType = SCHEDULED
          , scheduleItemVehicleInformation = VehicleInformation Nothing Nothing
          }]
      , [ ScheduleItem
          { tripId = "trip with skipped stop"
          , stop = Stop
            { stopIdentifier = "600202"
            , stopWalktime = 0
            , stopName = ""
            }
          , serviceName = "S2"
          , scheduledDepartureTime = TimeOfDay 10 30 0
          , departureDelay = 0
          , departureTime = TimeOfDay 10 30 0
          , scheduleType = CANCELED
          , scheduleItemVehicleInformation = VehicleInformation Nothing Nothing
          }])
    , ( "service congested and full"
      , makeFeedWithVehiclePosition
      , [ ScheduleItem
          { tripId = "trip congested and full"
          , stop = Stop
            { stopIdentifier = "600202"
            , stopWalktime = 0
            , stopName = ""
            }
          , serviceName = "S2"
          , scheduledDepartureTime = TimeOfDay 10 30 0
          , departureDelay = 0
          , departureTime = TimeOfDay 10 30 0
          , scheduleType = SCHEDULED
          , scheduleItemVehicleInformation = VehicleInformation Nothing Nothing
          }]
      , [ ScheduleItem
          { tripId = "trip congested and full"
          , stop = Stop
            { stopIdentifier = "600202"
            , stopWalktime = 0
            , stopName = ""
            }
          , serviceName = "S2"
          , scheduledDepartureTime = TimeOfDay 10 30 0
          , departureDelay = 0
          , departureTime = TimeOfDay 10 30 0
          , scheduleType = CANCELED
          , scheduleItemVehicleInformation = VehicleInformation (Just 100) (Just 100)
          }])
    ]

testDepartureWithDelay ::
  TestTree
testDepartureWithDelay = testGroup "check departure with delay" $ makeTest <$>
  [ ("delayed", departureTimeWithDelay (TimeOfDay 7 0 0) 30, TimeOfDay 7 0 30)
  , ("ahead", departureTimeWithDelay (TimeOfDay 7 0 0) (-30), TimeOfDay 6 59 30)
  ]

makeTest (name, input, expected) = testCase name $ input @?= expected
