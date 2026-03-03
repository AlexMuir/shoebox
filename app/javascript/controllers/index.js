import { application } from "./application"
import PersonAutocompleteController from "./person_autocomplete_controller"
application.register("person-autocomplete", PersonAutocompleteController)
import FileTimestampsController from "./file_timestamps_controller"
application.register("file-timestamps", FileTimestampsController)
import FaceTaggingController from "./face_tagging_controller"
application.register("face-tagging", FaceTaggingController)
import LocationAutocompleteController from "./location_autocomplete_controller"
application.register("location-autocomplete", LocationAutocompleteController)
import PhotoViewController from "./photo_view_controller"
application.register("photo-view", PhotoViewController)
