#ifndef MAINWINDOW_H_
#define MAINWINDOW_H_

#include <QMainWindow>
#include <QVector>
#include <string>

#include "cdc.h"

class InputCapture;
class QComboBox;
class QLineEdit;
class QPushButton;
class QTextEdit;

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit MainWindow(QWidget * parent = nullptr);
    ~MainWindow() override;

    static MainWindow * instance() { return instance_; }

private slots:
    void onConnect();
    void onDisconnect();
    void onMicToggle(bool checked);
    void onSpkToggle(bool checked);
    void onCamToggle(bool checked);
    void onMonToggle(bool checked);
    void onKbToggle(bool checked);
    void onMsToggle(bool checked);
    void onGpToggle(bool checked);
    void onCamEnum();
    void onCamListUpdate(QVector<QPair<QString, QString>> devices);
    void onCamComboChanged(int index);

private:
    Q_INVOKABLE void appendLog(const QString & text);
    void setupUi();
    void openSession();

    static void onLogCallback(CDCLogLevel level, const char * log);
    static void onCamListCallback(void * handle, const CDCCamDevice * devices, int count);

    static MainWindow * instance_;

    void * cdc_ = nullptr;
    bool opened_ = false;

    InputCapture * input_capture_ = nullptr;

    std::string url_utf8_;       // 持久化 url.toStdString() 供 CDCOpen 使用
    QLineEdit   * addr_edit_ = nullptr;
    QPushButton * connect_btn_ = nullptr;
    QPushButton * disconnect_btn_ = nullptr;
    QPushButton * mic_btn_ = nullptr;
    QPushButton * spk_btn_ = nullptr;
    QPushButton * cam_btn_ = nullptr;
    QPushButton * mon_btn_ = nullptr;
    QPushButton * kb_btn_ = nullptr;
    QPushButton * ms_btn_ = nullptr;
    QPushButton * gp_btn_ = nullptr;
    QPushButton * cam_enum_btn_ = nullptr;
    QComboBox   * cam_combo_ = nullptr;
    QTextEdit   * log_view_ = nullptr;

    std::string selected_cam_id_;
    std::string log_path_;           // 日志文件路径, 需存活至 CDCOpen 返回
};

#endif // MAINWINDOW_H_