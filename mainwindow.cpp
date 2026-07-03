#include "mainwindow.h"
#include "input_capture.h"

#include "cdc.h"

#include <QApplication>
#include <QComboBox>
#include <QDateTime>
#include <QDir>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QMetaObject>
#include <QPushButton>
#include <QStandardPaths>
#include <QTextEdit>
#include <QVBoxLayout>

MainWindow * MainWindow::instance_ = nullptr;

MainWindow::MainWindow(QWidget * parent)
    : QMainWindow(parent)
{
    instance_ = this;
    setWindowTitle("CDC Sample");
    resize(640, 480);
    setupUi();

    // 设置日志路径到应用数据目录
    const QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    QDir().mkpath(dataDir);
    QString logName = QString("cdc_sample_%1_%2.log")
                          .arg(QDateTime::currentDateTime().toString("yyyyMMdd-hhmmss"),
                               QString::number(QApplication::applicationPid()));
    log_path_ = QString("%1/%2").arg(dataDir, logName).toStdString();
    CDCSetLogPath(log_path_.c_str());

    appendLog(QString("[INFO] Log path: %1").arg(log_path_.c_str()));

    CDCSetLogCallback(&MainWindow::onLogCallback);

    CDCCallback cb{};
    cb.cam_list_func = &MainWindow::onCamListCallback;
    cdc_ = CDCCreate(&cb);
    if (cdc_)
        appendLog("[INFO] CDCCreate ok");
    else
        appendLog("[ERROR] CDCCreate failed");

    input_capture_ = new InputCapture(this, cdc_);
}

MainWindow::~MainWindow()
{
    delete input_capture_;
    input_capture_ = nullptr;

    instance_ = nullptr;
    if (opened_)
    {
        CDCClose(cdc_);
        opened_ = false;
    }
    CDCDestroy(cdc_);
    cdc_ = nullptr;
}

void MainWindow::setupUi()
{
    auto * central = new QWidget(this);
    setCentralWidget(central);

    auto * mainLayout = new QVBoxLayout(central);

    // 地址栏
    auto * addrLayout = new QHBoxLayout();
    auto * addrLabel = new QLabel("URL:", this);
    addr_edit_ = new QLineEdit(this);
    addr_edit_->setPlaceholderText("tcp://127.0.0.1:8000");
    addr_edit_->setText("tcp://127.0.0.1:8000");
    addrLayout->addWidget(addrLabel);
    addrLayout->addWidget(addr_edit_);
    mainLayout->addLayout(addrLayout);

    // 连接 / 断开
    auto * connLayout = new QHBoxLayout();
    connect_btn_ = new QPushButton("Open", this);
    disconnect_btn_ = new QPushButton("Close", this);
    disconnect_btn_->setEnabled(false);
    connLayout->addWidget(connect_btn_);
    connLayout->addWidget(disconnect_btn_);
    connLayout->addStretch();
    mainLayout->addLayout(connLayout);

    // 设备开关
    auto * devGroup = new QGroupBox("Devices", this);
    auto * devLayout = new QHBoxLayout(devGroup);
    mic_btn_ = new QPushButton("Mic", this);
    mic_btn_->setCheckable(true);
    spk_btn_ = new QPushButton("Spk", this);
    spk_btn_->setCheckable(true);
    cam_btn_ = new QPushButton("Cam", this);
    cam_btn_->setCheckable(true);
    mon_btn_ = new QPushButton("Mon", this);
    mon_btn_->setCheckable(true);
    devLayout->addWidget(mic_btn_);
    devLayout->addWidget(spk_btn_);
    devLayout->addWidget(cam_btn_);
    devLayout->addWidget(mon_btn_);
    devLayout->addStretch();
    mainLayout->addWidget(devGroup);

    // 输入捕获开关
    auto * inputGroup = new QGroupBox("Input Capture", this);
    auto * inputLayout = new QHBoxLayout(inputGroup);
    kb_btn_ = new QPushButton("KB", this);
    kb_btn_->setCheckable(true);
    kb_btn_->setToolTip("Toggle keyboard capture");
    ms_btn_ = new QPushButton("MS", this);
    ms_btn_->setCheckable(true);
    ms_btn_->setToolTip("Toggle mouse capture");
    gp_btn_ = new QPushButton("GP", this);
    gp_btn_->setCheckable(true);
    gp_btn_->setToolTip("Toggle gamepad capture");
    inputLayout->addWidget(kb_btn_);
    inputLayout->addWidget(ms_btn_);
    inputLayout->addWidget(gp_btn_);
    inputLayout->addStretch();
    mainLayout->addWidget(inputGroup);

    // 摄像头枚举
    auto * camGroup = new QGroupBox("Camera", this);
    auto * camLayout = new QHBoxLayout(camGroup);
    cam_combo_ = new QComboBox(this);
    cam_combo_->setMinimumWidth(200);
    cam_combo_->setToolTip("Select a camera device");
    camLayout->addWidget(cam_combo_);
    cam_enum_btn_ = new QPushButton("Enum", this);
    cam_enum_btn_->setToolTip("Enumerate camera devices via CDC");
    camLayout->addWidget(cam_enum_btn_);
    camLayout->addStretch();
    mainLayout->addWidget(camGroup);

    // 日志区
    log_view_ = new QTextEdit(this);
    log_view_->setReadOnly(true);
    mainLayout->addWidget(log_view_);

    // 信号连接
    connect(connect_btn_, &QPushButton::clicked, this, &MainWindow::onConnect);
    connect(disconnect_btn_, &QPushButton::clicked, this, &MainWindow::onDisconnect);
    connect(mic_btn_, &QPushButton::toggled, this, &MainWindow::onMicToggle);
    connect(spk_btn_, &QPushButton::toggled, this, &MainWindow::onSpkToggle);
    connect(cam_btn_, &QPushButton::toggled, this, &MainWindow::onCamToggle);
    connect(mon_btn_, &QPushButton::toggled, this, &MainWindow::onMonToggle);
    connect(kb_btn_, &QPushButton::toggled, this, &MainWindow::onKbToggle);
    connect(ms_btn_, &QPushButton::toggled, this, &MainWindow::onMsToggle);
    connect(gp_btn_, &QPushButton::toggled, this, &MainWindow::onGpToggle);
    connect(cam_enum_btn_, &QPushButton::clicked, this, &MainWindow::onCamEnum);
    connect(cam_combo_, QOverload<int>::of(&QComboBox::currentIndexChanged),
            this, &MainWindow::onCamComboChanged);
}

void MainWindow::appendLog(const QString & text)
{
    if (log_view_)
        log_view_->append(text);
}

void MainWindow::onConnect()
{
    openSession();
}

void MainWindow::onDisconnect()
{
    if (opened_)
    {
        CDCClose(cdc_);
        opened_ = false;
        appendLog("[INFO] CDC closed");
    }

    input_capture_->reset();

    kb_btn_->setChecked(false);
    ms_btn_->setChecked(false);
    gp_btn_->setChecked(false);
    connect_btn_->setEnabled(true);
    disconnect_btn_->setEnabled(false);
    mic_btn_->setChecked(false);
    spk_btn_->setChecked(false);
    cam_btn_->setChecked(false);
    mon_btn_->setChecked(false);
}

void MainWindow::onMicToggle(bool checked)
{
    CDCMicState(cdc_, checked);
    appendLog(QString("[INFO] Mic %1").arg(checked ? "on" : "off"));
}

void MainWindow::onSpkToggle(bool checked)
{
    CDCSpkState(cdc_, checked);
    appendLog(QString("[INFO] Spk %1").arg(checked ? "on" : "off"));
}

void MainWindow::onCamToggle(bool checked)
{
    CDCCamState(cdc_, checked);
    appendLog(QString("[INFO] Cam %1").arg(checked ? "on" : "off"));
}

void MainWindow::onMonToggle(bool checked)
{
    CDCMonState(cdc_, checked);
    appendLog(QString("[INFO] Mon %1").arg(checked ? "on" : "off"));
}

void MainWindow::onKbToggle(bool checked)
{
    input_capture_->setKbEnabled(checked);
    appendLog(QString("[INFO] Keyboard capture %1").arg(checked ? "on" : "off"));
}

void MainWindow::onMsToggle(bool checked)
{
    input_capture_->setMsEnabled(checked);
    appendLog(QString("[INFO] Mouse capture %1").arg(checked ? "on" : "off"));
}

void MainWindow::onGpToggle(bool checked)
{
    input_capture_->setGpEnabled(checked);
    appendLog(QString("[INFO] Gamepad capture %1").arg(checked ? "on" : "off"));
}

void MainWindow::onLogCallback(CDCLogLevel level, const char * log)
{
    if (!log) return;

    const char * tag = "[?]";
    switch (level)
    {
    case CDC_LOG_DEBUG: tag = "[D]"; break;
    case CDC_LOG_INFO:  tag = "[I]"; break;
    case CDC_LOG_WARN:  tag = "[W]"; break;
    case CDC_LOG_ERROR: tag = "[E]"; break;
    }

    auto * inst = instance();
    if (inst)
    {
        QString text = QString("%1 %2").arg(tag, QString::fromUtf8(log));
        QMetaObject::invokeMethod(inst, "appendLog", Qt::QueuedConnection,
                                  Q_ARG(QString, text));
    }
}

using CamDeviceVec = QVector<QPair<QString, QString>>;

void MainWindow::onCamListCallback(void * /*handle*/, const CDCCamDevice * devices, int count)
{
    CamDeviceVec list;
    for (int i = 0; i < count; ++i)
    {
        list.append({QString::fromUtf8(devices[i].name), QString::fromUtf8(devices[i].id)});
    }

    auto * inst = instance();
    if (inst)
    {
        QMetaObject::invokeMethod(inst, "onCamListUpdate", Qt::QueuedConnection,
                                   Q_ARG(CamDeviceVec, list));
    }
}

void MainWindow::onCamListUpdate(QVector<QPair<QString, QString>> devices)
{
    cam_combo_->clear();
    for (const auto & d : devices)
    {
        cam_combo_->addItem(QString("%1 (%2)").arg(d.first, d.second), d.second);
    }

    appendLog(QString("[INFO] Camera enum done, %1 device(s) found").arg(devices.size()));

    if (devices.isEmpty())
    {
        cam_combo_->addItem("(no camera found)", QString());
    }
}

void MainWindow::onCamEnum()
{
    appendLog("[INFO] Starting camera enumeration...");
    cam_combo_->clear();
    cam_combo_->addItem("(enumerating...)", QString());
    CDCCamEnumList(cdc_, 1 /* async */);
}

void MainWindow::onCamComboChanged(int index)
{
    if (index < 0) return;
    const QString id = cam_combo_->currentData().toString();
    selected_cam_id_ = id.toStdString();
    if (!selected_cam_id_.empty())
    {
        appendLog(QString("[INFO] Camera selected: %1").arg(selected_cam_id_.c_str()));
    }
}

void MainWindow::openSession()
{
    const QString url = addr_edit_->text().trimmed();
    if (url.isEmpty())
    {
        appendLog("[ERROR] URL is empty");
        return;
    }

    url_utf8_ = url.toStdString();   // persistent storage for cfg.url

    CDCConfig cfg{};
    cfg.url                = url_utf8_.c_str();
    cfg.flow_id            = nullptr;
    cfg.wnd.wnd            = nullptr;  // demo: no video render widget
    cfg.cam_name           = selected_cam_id_.empty() ? nullptr : selected_cam_id_.c_str();
    cfg.cam_resolution     = nullptr;  // default resolution
    cfg.cam_fps            = 30;
    cfg.connect_timeout_ms = 5000;
    cfg.retry_count        = 3;
    cfg.client_keepalive   = 1;
    cfg.keepalive_interval_ms = 3000;

    CDCOpen(cdc_, &cfg);

    // 设置各模块开关状态 (mic/spk/cam/mon 通过独立 API 控制)
    CDCMicState(cdc_, mic_btn_->isChecked());
    CDCSpkState(cdc_, spk_btn_->isChecked());
    CDCCamState(cdc_, cam_btn_->isChecked());
    CDCMonState(cdc_, mon_btn_->isChecked());

    opened_ = true;
    appendLog(QString("[INFO] CDCOpen called"));

    connect_btn_->setEnabled(false);
    disconnect_btn_->setEnabled(true);
}