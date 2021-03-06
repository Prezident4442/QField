/***************************************************************************
                            qgismobileapp.qml
                              -------------------
              begin                : 10.12.2014
              copyright            : (C) 2014 by Matthias Kuhn
              email                : matthias (at) opengis.ch
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

import QtQuick 2.11
import QtQuick.Controls 1.4 as Controls
import QtQuick.Controls 2.4
import QtQuick.Dialogs 1.2
import QtGraphicalEffects 1.0
import QtQml 2.2
import org.qgis 1.0
import org.qfield 1.0
import QtPositioning 5.11
import "js/style.js" as Style

import '.'

ApplicationWindow {
  id: mainWindow
  visible: true
  //minimumWidth: 300
  //minimumHeight: 300

  FocusStack{
      id: focusstack
  }

  //this keyHandler is because otherwise the back-key is not handled in the mainWindow. Probably this could be solved cuter.

  Item {
    id: keyHandler
    objectName: "keyHandler"

    visible: true
    focus: true

    Keys.onReleased: {
      console.warn( "KEY PRESS " + event.key )
      if ( event.key === Qt.Key_Back ||
        event.key === Qt.Key_Escape ) {
        mainWindow.close();
        event.accepted = true
      }
    }

    Component.onCompleted: focusstack.addFocusTaker( this )
  }

  Item {
    id: stateMachine

    states: [
      State {
        name: "browse"
      },

      State {
        name: "digitize"
      }
    ]
    state: "browse"
  }

  /**
   * The position source to access the GPS
   */
  TransformedPositionSource {
    id: positionSource
    active: settings.valueBool( "/QField/Positioning/Active", false )
    destinationCrs: mapCanvas.mapSettings.destinationCrs
  }

  Item {
    id: positionInformationView
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    visible: settings.valueBool( "/QField/Positioning/ShowInformationView", false )

    height: childrenRect.height
    width: parent.width

    PositionInformationView {
      positionSource: positionSource
      crs: mapCanvas.mapSettings.destinationCrs
    }
  }

  Item {
    /*
     * This is the map canvas
     * On top of it are the base map and other items like GPS icon...
     */
    id: mapCanvas

    /* Initialize a MapSettings object. This will contain information about
     * the current canvas extent. It is shared between the base map and all
     * map canvas items and is used to transform map coordinates to pixel
     * coordinates.
     * It may change any time and items that hold a reference to this property
     * are responsible to handle this properly.
     */
    property MapSettings mapSettings: mapCanvasMap.mapSettings

    /* Placement and size. Share right anchor with featureForm */
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: positionInformationView.visible ? positionInformationView.top : parent.bottom

    /* The base map */
    MapCanvas {
      id: mapCanvasMap
      incrementalRendering: qfieldSettings.incrementalRendering

      anchors.fill: parent

      onClicked: {
        if (locatorItem.searching)
        {
          locatorItem.searching = false
        }
        else if( !overlayFeatureFormDrawer.visible )
        {
          identifyTool.identify( Qt.point( mouse.x, mouse.y ) )
        }
      }
      Component.onCompleted: platformUtilities.showRateThisApp()
    }

  /**************************************************
   * Position markers
   * - Coordinate Locator
   * - GPS Marker
   * - Identify Highlight
   * - Digitizing Rubberband
   **************************************************/

    /* A transformation node for overlays in map coordinates */
    Item {
      anchors.fill: parent

      transform: MapTransform {
        mapSettings: mapCanvas.mapSettings
      }

      /** A rubberband for ditizing **/
      Rubberband {
        id: digitizingRubberband
        width: 2 * dp

        mapSettings: mapCanvas.mapSettings

        model: RubberbandModel {
          frozen: false
          currentCoordinate: coordinateLocator.currentCoordinate
          vectorLayer: dashBoard.currentLayer
          crs: mapCanvas.mapSettings.destinationCrs
        }

        anchors.fill: parent

        visible: stateMachine.state === "digitize"
      }

      /** The identify tool **/
      IdentifyTool {
        id: identifyTool

        mapSettings: mapCanvas.mapSettings
        model: featureForm.model
      }
    }

    /** A coordinate locator for digitizing **/
    CoordinateLocator {
      id: coordinateLocator
      anchors.fill: parent
      visible: stateMachine.state === "digitize"
      highlightColor: digitizingToolbar.isDigitizing ? digitizingRubberband.color : "#CFD8DC"
      mapSettings: mapCanvas.mapSettings
      currentLayer: dashBoard.currentLayer
      overrideLocation: gpsLinkButton.linkActive ? positionSource.projectedPosition : undefined
    }

    /* GPS marker  */
    LocationMarker {
      id: locationMarker
      mapSettings: mapCanvas.mapSettings
      anchors.fill: parent
      visible: positionSource.active
      location: positionSource.projectedPosition
    }

    /* Rubberband for vertices  */
    Item {
      VertexRubberband {
        id: vertexRubberband
        model: vertexModel
        mapSettings: mapCanvas.mapSettings
      }

      Rubberband {
        id: editingRubberBand
        vertexModel: vertexModel
        mapSettings: mapCanvas.mapSettings
        width: 2 * dp

        transform: MapTransform {
          mapSettings: mapCanvas.mapSettings
        }
      }
    }

    /* Locator Highlight */
    GeometryHighlighter {
      id: locatorHighlightItem
      //width: 10 * dp
      //color: "yellow"
    }

    /* Highlight the currently selected item on the feature list */
    FeatureListSelectionHighlight {
      selectionModel: featureForm.selection
      mapSettings: mapCanvas.mapSettings

      //model: featureForm.model
      //selection: featureForm.selection

      color: "yellow"
      selectionColor: "#ff7777"
      width: 5 * dp
    }
  }

  /**************************************************
   * Map Canvas Decorations like
   * - Position Information View
   * - Scale Bar
   **************************************************/

  Text {
    DistanceArea {
      id: digitizingGeometryMeasure

      property VectorLayer currentLayer: dashBoard.currentLayer

      rubberbandModel: digitizingRubberband.model
      project: qgisProject
      crs: qgisProject.crs
    }

    x: mainWindow.width / 2 + 24 * dp
    y: mainWindow.height / 2 + 24 * dp

    text: qfieldSettings.numericalDigitizingInformation && stateMachine.state === "digitize" ?
            '<p>%1 / %2</p>%3%4'
              .arg(coordinateLocator.currentCoordinate.x.toFixed(3))
              .arg(coordinateLocator.currentCoordinate.y.toFixed(3))

              .arg(digitizingGeometryMeasure.lengthValid ? '<p>%1 %2</p>'
                .arg(UnitTypes.formatDistance( digitizingGeometryMeasure.segmentLength, 3, digitizingGeometryMeasure.lengthUnits ) )
                .arg(digitizingGeometryMeasure.length !== -1 ? '(%1)'.arg(UnitTypes.formatDistance( digitizingGeometryMeasure.length, 3, digitizingGeometryMeasure.lengthUnits ) ) : '' ) : '' )

              .arg(digitizingGeometryMeasure.areaValid ? '<p>%1</p>'.arg(UnitTypes.formatArea( digitizingGeometryMeasure.area, 3, digitizingGeometryMeasure.areaUnits ) ) : '' )
            : ''

    font.pointSize: 12
    style: Text.Outline
    font.weight: Font.Bold
    styleColor: "white"
  }

  ScaleBar {
    visible: qfieldSettings.showScaleBar
    mapSettings: mapCanvas.mapSettings

    anchors.left: mapCanvas.left
    anchors.bottom: mapCanvas.bottom
    anchors.margins: 10 * dp
  }

  DropShadow {
    anchors.fill: featureForm
    horizontalOffset: -2 * dp
    verticalOffset: 0
    radius: 6.0 * dp
    samples: 17
    color: "#80000000"
    source: featureForm
  }

  LocatorItem {
    id: locatorItem

    width: mainWindow.width < 300 * dp ? mainWindow.width - anchors.margins - mainMenuBar.width : 200 * dp
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 10 * dp
  }

  DashBoard {
    id: dashBoard
    allowLayerChange: !digitizingToolbar.isDigitizing
    mapSettings: mapCanvas.mapSettings
    width: open ? Math.min( 300 * dp, mainWindow.width) : 0
  }

  DropShadow {
    anchors.fill: dashBoard
    horizontalOffset: 2 * dp
    verticalOffset: 0
    radius: 6.0 * dp
    samples: 17
    color: "#80000000"
    source: dashBoard
  }

  /* The main menu */
  Row {
    id: mainMenuBar
    width: childrenRect.width + 8 * dp
    height: childrenRect.height + 8 * dp

    Button {
      id: menuButton
      round: true
      iconSource: Style.getThemeIcon( "ic_menu_white_24dp" )
      onClicked: dashBoard.visible = !dashBoard.visible
      bgcolor: dashBoard.visible ? "#80CC28" : "#212121"
      anchors.left: mainMenuBar.left
      anchors.leftMargin: 4 * dp
      anchors.top: mainMenuBar.top
      anchors.topMargin: 4 * dp
    }
  }

  Column {
    id: mainToolBar
    anchors.left: dashBoard.right
    anchors.leftMargin: 4 * dp
    anchors.top: mainMenuBar.bottom
    anchors.topMargin: 4 * dp
    spacing: 4 * dp

    Button {
      id: gpsButton
      state: positionSource.active ? "On" : "Off"
      visible: positionSource.valid
      round: true

      bgcolor: "#64B5F6"

      states: [
        State {

          name: "Off"
          PropertyChanges {
            target: gpsButton
            iconSource: Style.getThemeIcon( "ic_location_disabled_white_24dp" )
            bgcolor: "lightgrey"
          }
        },

        State {
          name: "On"
          PropertyChanges {
            target: gpsButton
            bgcolor: "#64B5F6"
            iconSource: positionSource.position.latitudeValid ? Style.getThemeIcon( "ic_my_location_white_24dp" ) : Style.getThemeIcon( "ic_gps_not_fixed_white_24dp" )
          }
        }
      ]

      onClicked: {
        console.warn("Centering")
        if ( positionSource.projectedPosition.x )
        {
          console.warn("Centering to " + positionSource.projectedPosition.x + " " + positionSource.projectedPosition.y )
          mapCanvas.mapSettings.setCenter(positionSource.projectedPosition)

          if ( !positionSource.active )
          {
            positionSource.active = true;
            displayToast( qsTr( "Activating positioning service..." ) )
          }
        }
        else
        {
          if ( positionSource.valid )
          {
            if ( positionSource.active )
            {
              displayToast( qsTr( "Waiting for location..." ) )
            }
            else
            {
              positionSource.active = true
              displayToast( qsTr( "Activating positioning service..." ) )
            }
          }
        }
      }

      onPressAndHold: {
        gpsMenu.popup()
      }

      function toggleGps() {
        switch ( gpsButton.state )
        {
          case "Off":
            gpsButton.state = "On"
            displayToast( qsTr( "Positioning activated" ) )
            break;

          case "On":
            gpsButton.state = "Off"
            displayToast( qsTr( "Positioning turned off" ) )
            break;
        }
      }
    }

    Button {
      id: gpsLinkButton
      visible: gpsButton.state == "On" && stateMachine.state === "digitize"
      round: true
      checkable: true

      iconSource: linkActive ? Style.getThemeIcon( "ic_gps_link_activated_white_24dp" ) : Style.getThemeIcon( "ic_gps_link_white_24dp" )

      readonly property bool linkActive: gpsButton.state == "On" && checked

      onClicked: gpsLinkButton.checked = !gpsLinkButton.checked
    }
  }

  DigitizingToolbar {
    id: digitizingToolbar

    anchors.bottom: mapCanvas.bottom
    anchors.right: mapCanvas.right

    stateVisible: ( stateMachine.state === "digitize"
                   && dashBoard.currentLayer
                   && !dashBoard.currentLayer.readOnly
                   && !geometryEditingToolbar.stateVisible )
    rubberbandModel: digitizingRubberband.model

    FeatureModel {
      id: digitizingFeature
      currentLayer: dashBoard.currentLayer
      positionSourceName: positionSource.name

      geometry: Geometry {
        id: digitizingGeometry
        rubberbandModel: digitizingRubberband.model
        vectorLayer: dashBoard.currentLayer
      }
    }

    onVertexAdded: {
      coordinateLocator.flash()
      digitizingRubberband.model.addVertex()
    }

    onVertexRemoved:
    {
      digitizingRubberband.model.removeVertex()
    }

    onCancel:
    {
      digitizingRubberband.model.reset()
    }

    onConfirm: {
      if (digitizingRubberband.model.geometryType === QgsWkbTypes.NullGeometry )
      {
        digitizingRubberband.model.reset()
      }
      else
      {
        coordinateLocator.flash()
        digitizingFeature.geometry.applyRubberband()
        digitizingFeature.applyGeometry()
        digitizingRubberband.model.frozen = true
      }

      if ( !digitizingFeature.suppressFeatureForm() )
      {
        digitizingFeature.resetAttributes();
        overlayFeatureFormDrawer.open()
        overlayFeatureFormDrawer.state = "Add"
        overlayFeatureFormDrawer.featureForm.reset()
      }
      else
      {
        digitizingFeature.create()
        digitizingRubberband.model.reset()
      }
    }
  }

  GeometryEditingToolbar {
    id: geometryEditingToolbar

    featureModel: geometryEditingFeature
    mapSettings: mapCanvas.mapSettings

    anchors.bottom: mapCanvas.bottom
    anchors.right: mapCanvas.right

    stateVisible: ( stateMachine.state === "digitize" && vertexModel.vertexCount > 0 )
  }


  Controls.Menu {
    id: mainMenu
    title: qsTr( "Main Menu" )

    Controls.MenuItem {
      id: openProjectMenuItem
      property ProjectSource __projectSource

      text: qsTr( "Open Project" )
      iconSource: Style.getThemeIcon( "ic_map_white_24dp" )
      onTriggered: {
        __projectSource = platformUtilities.openProject()
      }
    }

    Controls.MenuSeparator {}

    Controls.MenuItem {
      text: qsTr( "Settings" )

      onTriggered: {
        qfieldSettings.visible = true
      }
    }

    Controls.MenuItem {
      text: qsTr( "About" )

      onTriggered: {
        aboutDialog.visible = true
      }
    }

    Controls.MenuItem {
      text: qsTr( "Log" )

      onTriggered: {
        messageLog.visible = true
      }
    }

    Controls.Menu {
      id: printMenu
      title: qsTr( "Print to PDF" )

      Instantiator {

        id: layoutListInstantiator

        model: PrintLayoutListModel {
        }

        Controls.MenuItem {
          text: Title

          onTriggered: {
            iface.print( Index )
          }
        }
        onObjectAdded: printMenu.insertItem(index, object)
        onObjectRemoved: printMenu.removeItem(object)
      }

      Connections {
        target: iface

        onLoadProjectEnded: {
          layoutListInstantiator.model.project = qgisProject
          layoutListInstantiator.model.reloadModel()
          printMenu.visible = layoutListInstantiator.model.rowCount()
        }
      }
    }

    /*
    We removed this MenuItem part, because usually a mobile app has not the functionality to quit.
    But we keep the code in case, the concept changes or we need to close the app completely (remove from background)
    */

    /*
    Controls.MenuSeparator {}

    Controls.MenuItem {
      text: qsTr( "Quit" )
      iconSource: Style.getThemeIcon( "ic_close_white_24dp" )
      onTriggered: {
        Qt.quit()
      }
    }
    */
  }

  Controls.Menu {
    id: gpsMenu
    title: qsTr( "Positioning Options" )

    Controls.MenuItem {
      text: qsTr( "Enable Positioning" )
      checkable: true
      checked: positionSource.active
      onCheckedChanged: {
        if ( checked && platformUtilities.checkPositioningPermissions() ) {
          positionSource.active = checked
        }
        else {
          displayToast( qsTr( "QField has no permissions to use positioning." ) )
          positionSource.active = false
        }

      }
    }

    Controls.MenuItem {
      text: qsTr( "Center current location" )
      onTriggered: {
        var coord = positionSource.position.coordinate;
        var loc = Qt.point( coord.longitude, coord.latitude );
        mapCanvas.mapSettings.setCenter( locationMarker.coordinateTransform.transform( loc ) )
      }
    }

    Controls.MenuSeparator {}

    Controls.MenuItem {
      text: qsTr( "Show position information" )
      checkable: true
      checked: settings.valueBool( "/QField/Positioning/ShowInformationView", false )
      onCheckedChanged:
      {
        settings.setValue( "/QField/Positioning/ShowInformationView", checked )
        positionInformationView.visible = checked
      }
    }
  }

  Image {
    id: alertIcon
    source: Style.getThemeIcon( "ic_add_alert_black_18dp" )

    visible: messageLog.unreadMessages

    anchors.right: mapCanvas.right
    anchors.top: parent.top
    anchors.margins: 4 * dp
    width: 36 * dp
    height: 36 * dp

    MouseArea {
      anchors.fill: parent
      onClicked: messageLog.visible = true
    }
  }

  /* The feature form */
  FeatureListForm {
    id: featureForm
    objectName: "featureForm"
    mapSettings: mapCanvas.mapSettings

    visible: state != "Hidden"
    focus: visible

    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
    border { color: "lightGray"; width: 1 }
    allowEdit: stateMachine.state === "digitize"

    model: MultiFeatureListModel {}

    selection: FeatureListModelSelection {
      id: featureListModelSelection
      model: featureForm.model
    }

    selectionColor: "#ff7777"

    onShowMessage: displayToast(message)

    onEditGeometry: {
      vertexModel.geometry = featureForm.selection.selectedGeometry
      vertexModel.crs = featureForm.selection.selectedLayer.crs
      geometryEditingFeature.currentLayer = featureForm.selection.selectedLayer
      geometryEditingFeature.feature = featureForm.selection.selectedFeature

      if (!vertexModel.editingAllowed)
      {
        displayToast( qsTr( "Editing of multi geometry layer is not supported yet." ) )
        vertexModel.clear()
      }
      else
      {
        featureForm.state = "Hidden"
      }
    }

    Component.onCompleted: focusstack.addFocusTaker( this )

    //that the focus is set by selecting the empty space
    MouseArea {
      anchors.fill: parent
      propagateComposedEvents: true
      enabled: !parent.activeFocus

      //onPressed because onClicked shall be handled in underlying MouseArea
      onPressed: {
        parent.focus=true
        mouse.accepted=false
      }
    }
  }

  OverlayFeatureFormDrawer {
    id: overlayFeatureFormDrawer
    featureModel: digitizingFeature
    width: qfieldSettings.fullScreenIdentifyView || mainWindow.width<300*dp? mainWindow.width : Math.min(Math.max(200*dp, mainWindow.width/3), mainWindow.width)
  }

  Keys.onReleased: {
    if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
      event.accepted = true
    }
  }

  function displayToast( message ) {
    //toastMessage.text = message
    toast.show(message)
  }

  Rectangle {
    id: busyMessage
    anchors.fill: parent
    color: "#272727"
    opacity: 0.5
    visible: false

    Controls.BusyIndicator {
      id: busyMessageIndicator
      anchors.centerIn: parent
      running: true
      width: 100 * dp
      height: 100 * dp
    }

    Text {
      id: busyMessageText
      anchors.top: busyMessageIndicator.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      text: qsTr( "Loading Project" )
    }

    Connections {
      target: iface

      onLoadProjectStarted: {
        busyMessageText.text = qsTr( "Loading Project: %1" ).arg( path )
        busyMessage.visible = true
      }

      onLoadProjectEnded: {
        busyMessage.visible = false
        openProjectDialog.folder = qgisProject.homePath
      }
    }
  }

  Controls.BusyIndicator {
    id: busyIndicator
    anchors.centerIn: mapCanvas
    width: 36 * dp
    height: 36 * dp
    running: mapCanvasMap.isRendering
  }

  MessageLog {
    id: messageLog
    anchors.fill: parent
    focus: visible

    model: MessageLogModel {}

    visible: false

    Keys.onReleased: {
      if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
        event.accepted = true
        visible = false
      }
    }

    Component.onCompleted: focusstack.addFocusTaker( this )
  }

  BadLayerItem {
    id: badLayersView

    anchors.fill: parent
    model: BadLayerHandler {
      project: qgisProject

      onBadLayersFound: {
        badLayersView.visible = true
      }
    }

    visible: false

    onFinished: {
      visible = false
    }
  }

  About {
    id: aboutDialog
    anchors.fill: parent
    focus: visible

    visible: false

    Keys.onReleased: {
      if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
        event.accepted = true
        visible = false
      }
    }

    Component.onCompleted: focusstack.addFocusTaker( this )
  }

  FileDialog {
    id: openProjectDialog
    title: qsTr( "Open project" )
    visible: false
    nameFilters: [ qsTr( "QGIS projects (*.qgs)" ), qsTr( "All files (*)" ) ]

    width: parent.width
    height: parent.height

    onAccepted: {
      iface.loadProject( openProjectDialog.fileUrl.toString().slice(7) )
      mainWindow.keyHandler.focus=true
    }
  }

  QFieldSettings {
    id: qfieldSettings

    anchors.fill: parent
    visible: false
    focus: visible

    onFinished: {
      visible = false
    }

    Keys.onReleased: {
      if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
        event.accepted = true
        finished()
      }
    }

    Component.onCompleted: focusstack.addFocusTaker( this )
  }

  WelcomeScreen {
    id: welcomeScreen
    anchors.fill: parent
    visible: !settings.value( "/QField/FirstRunFlag", false )
    property ProjectSource __projectSource

    onShowOpenProjectDialog: {
      welcomeScreen.visible = false
      __projectSource = platformUtilities.openProject()
    }
  }
  // Toast
  Popup {
      id: toast
      opacity: 0
      height: 40 * dp;
      width: parent.width
      y: parent.height - 112 * dp
      margins: 0
      background: none
      closePolicy: Popup.NoAutoClose

      function show(text) {
          toastMessage.text = text
          toast.open()
          toastContent.visible = true
          toast.opacity = 1
          toastTimer.start()
      }

      Behavior on opacity {
        NumberAnimation { duration: 500 }
      }

      Rectangle {
          id: toastContent
        color: "#272727"

        height: 40 * dp
        width: ( (toastMessage.width + 16 * dp) <= 192 * dp ) ? 192 * dp : toastMessage.width + 16 * dp

        anchors.centerIn: parent

        radius: 20 * dp

        z: 1

        Text {
          id: toastMessage
          anchors.centerIn: parent
          font.pixelSize: 16 * dp
          color: "#ffffff"
        }
      }

      // Visible only for 3 seconds
      Timer {
          id: toastTimer
          interval: 3000
          onTriggered: {
              toast.opacity = 0
          }
      }

      onOpacityChanged: {

          if ( opacity == 0 ) {
              toastContent.visible = false
              toast.close()
          }
      }
  }

  DropArea {
    id: dropArea
    anchors.fill: parent
    onEntered: {
      if ( drag.urls.length !== 1
         || !validateFileExtension( drag.urls[0] ) ) {
          drag.accepted = false
      }
      else {
        drag.accept (Qt.CopyAction)
        drag.accepted = true
      }
    }
    onDropped: {
      iface.loadProject( drop.urls[0] )
    }

    function validateFileExtension(filePath) {
      return filePath.split('.').pop() === "qgs" || filePath.split('.').pop() === "qgz"
    }
  }

  property bool alreadyCloseRequested: false

  onClosing: {
      if( !alreadyCloseRequested )
      {
        close.accepted = false
        alreadyCloseRequested = true
        displayToast( qsTr( "Press back again to close project and app" ) )
        closingTimer.start()
      }
      else
      {
        close.accepted = true
      }
  }

  Timer {
    id: closingTimer
    interval: 2000
    onTriggered: {
        alreadyCloseRequested = false
    }
  }

  Connections {
    target: openProjectMenuItem.__projectSource

    onProjectOpened: {
      iface.loadProject( path )
    }
  }

  Connections {
    target: welcomeScreen.__projectSource

    onProjectOpened: {
      iface.loadProject( path )
    }
  }

  // ! MODELS !
  FeatureModel {
    id: geometryEditingFeature
    currentLayer: null
    positionSourceName: positionSource.name
    vertexModel: vertexModel
  }

  VertexModel {
      id: vertexModel
      currentPoint: coordinateLocator.currentCoordinate
      mapSettings: mapCanvas.mapSettings
  }
}

