#include "mainwindow.h"

#include "cdc.h"

#include <QCheckBox>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>
#include <QTextEdit>
#include <QVBoxLayout>

MainWindow::MainWindow(QWidget * parent)
    : QMainWindow(parent)
{
    setWindowTitle("CDC Sample");
    resize(640, 480);
    setupUi();
}

MainWindow::~MainWindow()
{
    if (cdc_)
    {
        CDCClose(cdc_);
        CDCDestroy(cdc_);
        cdc_ = nullptr;
    }
}

/*
 * setupUi
 * 构建界面布局: 地址栏 + 连接/断开按钮 + 设备开关 + 日志区
 */
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
}

/*
 * appendLog
 * 向日志窗口追加一行文本
 * @param text  日志内容
 */
void MainWindow::appendLog(const QString & text)
{
    if (log_view_)
    {
        log_view_->append(text);
    }
}

/*
 * onConnect
 * 创建并打开 CDC 会话
 */
void MainWindow::onConnect()
{
    if (cdc_)
    {
        appendLog("[WARN] Already connected");
        return;
    }

    const QString url = addr_edit_->text().trimmed();
    if (url.isEmpty())
    {
        appendLog("[ERROR] URL is empty");
        return;
    }

    CDCConfig cfg;
    cfg.connect_timeout_ms = 5000;
    cfg.retry_count        = 3;
    cfg.mic_enabled        = mic_btn_->isChecked();
    cfg.spk_enabled        = spk_btn_->isChecked();
    cfg.cam_enabled        = cam_btn_->isChecked();
    cfg.mon_enabled        = mon_btn_->isChecked();

    CDCCallback cb{};
    cdc_ = CDCCreate(url.toUtf8().constData(), &cfg, nullptr, &cb);
    if (!cdc_)
    {
        appendLog("[ERROR] CDCCreate failed");
        return;
    }

    appendLog("[INFO] CDCCreate ok, opening...");
    CDCOpen(cdc_);
    appendLog("[INFO] CDCOpen called");

    connect_btn_->setEnabled(false);
    disconnect_btn_->setEnabled(true);
}

/*
 * onDisconnect
 * 关闭并销毁 CDC 会话
 */
void MainWindow::onDisconnect()
{
    if (!cdc_) return;

    CDCClose(cdc_);
    CDCDestroy(cdc_);
    cdc_ = nullptr;
    appendLog("[INFO] CDC closed");

    connect_btn_->setEnabled(true);
    disconnect_btn_->setEnabled(false);
    mic_btn_->setChecked(false);
    spk_btn_->setChecked(false);
    cam_btn_->setChecked(false);
    mon_btn_->setChecked(false);
}

void MainWindow::onMicToggle(bool checked)
{
    if (cdc_)
    {
        CDCMicState(cdc_, checked);
        appendLog(QString("[INFO] Mic %1").arg(checked ? "on" : "off"));
    }
}

void MainWindow::onSpkToggle(bool checked)
{
    if (cdc_)
    {
        CDCSpkState(cdc_, checked);
        appendLog(QString("[INFO] Spk %1").arg(checked ? "on" : "off"));
    }
}

void MainWindow::onCamToggle(bool checked)
{
    if (cdc_)
    {
        CDCCamState(cdc_, checked);
        appendLog(QString("[INFO] Cam %1").arg(checked ? "on" : "off"));
    }
}

void MainWindow::onMonToggle(bool checked)
{
    if (cdc_)
    {
        CDCMonState(cdc_, checked);
        appendLog(QString("[INFO] Mon %1").arg(checked ? "on" : "off"));
    }
}