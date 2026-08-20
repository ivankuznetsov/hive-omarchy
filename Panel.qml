import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.ivankuznetsov.hive-status"
  ipcTarget: "io.github.ivankuznetsov.hive-status"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function openHive(instance) {
    if (instance && instance.url) openExternalUrl(String(instance.url))
  }

  function openTask(task) {
    if (task && task.web_url) openExternalUrl(String(task.web_url))
  }

  function openTaskError(instance) {
    if (instance && instance.tailscale_auth_url) openExternalUrl(String(instance.tailscale_auth_url))
  }

  function openExternalUrl(url) {
    var target = String(url || "")
    if (target.indexOf("https://") !== 0 && target.indexOf("http://") !== 0) return
    Quickshell.execDetached(["omarchy-launch-browser", target])
    root.close()
  }

  function stateColor(instance) {
    if (!instance || instance.reachable !== true) return root.urgent
    if (instance.daemon && instance.daemon.running === true) return root.foreground
    return root.urgent
  }

  onOpenedChanged: if (opened) {
    hive.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Service {
    id: hive
    settings: root.settings
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: hive.barLabel
    active: hive.runningTaskCount > 0
    dimmed: hive.configured === 0 || (!hive.refreshing && hive.reachable === 0)
    tooltipText: hive.tooltipText
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.MiddleButton) hive.refresh()
      else if (mouseButton === Qt.RightButton && hive.instances.length === 1) root.openHive(hive.instances[0])
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") hive.refresh()
        else if ((text === "o" || text === "O") && hive.instances.length > 0) root.openHive(hive.instances[0])
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: contentColumn
          width: parent.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Hive"
            meta: hive.configured + " configured · " + hive.daemonRunning + " running · " + hive.runningTaskCount + " active tasks"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: hive.reachable > 0 ? 1.0 : 0.55
            iconComponent: Component {
              Text {
                text: "🐝"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Text {
            visible: hive.refreshing || hive.lastError !== ""
            width: parent.width
            text: hive.refreshing ? "Refreshing all Hive instances…" : hive.lastError
            color: hive.lastError !== "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Text {
            visible: hive.instances.length === 0 && !hive.refreshing
            width: parent.width
            text: "No Hive instances are configured. Add an instancesJson list in the bar widget settings."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }

          Column {
            width: parent.width
            spacing: Style.space(10)

            Repeater {
              model: hive.instances

              Rectangle {
                required property var modelData
                width: contentColumn.width
                implicitHeight: instanceColumn.implicitHeight + Style.space(20)
                radius: Style.space(8)
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)

                Column {
                  id: instanceColumn
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: Style.space(10)
                  spacing: Style.space(7)

                  RowLayout {
                    width: parent.width
                    spacing: Style.space(7)

                    Rectangle {
                      width: Style.space(7)
                      height: width
                      radius: width / 2
                      color: root.stateColor(modelData)
                      opacity: modelData.reachable === true ? 1.0 : 0.65
                    }

                    Text {
                      text: String(modelData.name || "Hive")
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    Text {
                      text: Model.instanceState(modelData)
                      color: modelData.daemon && modelData.daemon.running === true ? root.foreground : root.urgent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                    }

                    Text {
                      text: "Open ↗"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                    }
                  }

                  Text {
                    width: parent.width
                    text: String(modelData.url || "")
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideMiddle
                  }

                  Text {
                    visible: !modelData.tasks || modelData.tasks.length === 0
                    width: parent.width
                    text: Model.instanceDetail(modelData)
                    color: modelData.tailscale_auth_url ? root.foreground : (modelData.task_error ? root.urgent : root.dim)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.WordWrap

                    MouseArea {
                      anchors.fill: parent
                      enabled: !!modelData.tailscale_auth_url
                      hoverEnabled: enabled
                      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                      onClicked: root.openTaskError(modelData)
                    }
                  }

                  Rectangle {
                    visible: !!modelData.tailscale_auth_url
                    width: parent.width
                    implicitHeight: Style.space(34)
                    radius: Style.space(6)
                    color: authMouse.containsMouse
                      ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10)
                      : "transparent"

                    RowLayout {
                      anchors.fill: parent
                      anchors.leftMargin: Style.space(8)
                      anchors.rightMargin: Style.space(8)

                      Text {
                        text: "Authorize Tailscale"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                        Layout.fillWidth: true
                      }

                      Text {
                        text: "↗"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                      }
                    }

                    MouseArea {
                      id: authMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.openTaskError(modelData)
                    }
                  }

                  Column {
                    visible: modelData.tasks && modelData.tasks.length > 0
                    width: parent.width
                    spacing: Style.space(5)

                    Repeater {
                      model: modelData.tasks || []

                      Rectangle {
                        required property var modelData
                        width: instanceColumn.width
                        height: Style.space(42)
                        radius: Style.space(6)
                        color: taskMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10) : "transparent"

                        RowLayout {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(7)
                          anchors.rightMargin: Style.space(7)
                          spacing: Style.space(7)

                          Text {
                            text: "●"
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.bodySmall
                          }

                          Column {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                              width: parent.width
                              text: String(modelData.title || modelData.slug || "Task")
                              color: root.foreground
                              font.family: root.fontFamily
                              font.pixelSize: Style.font.bodySmall
                              font.bold: true
                              elide: Text.ElideRight
                            }

                            Text {
                              width: parent.width
                              text: String(modelData.project || "") + " · " + String(modelData.stage || "") + " · " + String(modelData.status || "running")
                              color: root.dim
                              font.family: root.fontFamily
                              font.pixelSize: Style.font.bodySmall
                              elide: Text.ElideRight
                            }
                          }

                          Text {
                            text: "↗"
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                          }
                        }

                        MouseArea {
                          id: taskMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.openTask(modelData)
                        }
                      }
                    }
                  }
                }

                MouseArea {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  height: Style.space(62)
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.openHive(modelData)
                }
              }
            }
          }

          Text {
            visible: hive.status.generatedAt !== ""
            width: parent.width
            text: "Updated " + String(hive.status.generatedAt).substring(11, 19) + " · R refresh · O open"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }
}
