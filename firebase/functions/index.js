const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const cheerio = require('cheerio');
const crypto = require('crypto');

admin.initializeApp();

const db = admin.firestore();

/**
 * Scheduled Scraper Function
 * Runs every 15 minutes to check for new notices.
 */
exports.checkNewNotices = functions.pubsub.schedule('every 15 minutes').onRun(async (context) => {
    const url = 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=25&key=806'; // 대학소식
    
    try {
        const response = await axios.get(url, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            },
            timeout: 10000
        });

        const $ = cheerio.load(response.data);
        const rows = $('tbody tr').toArray();

        for (const row of rows) {
            const titleEl = $(row).find('.p-subject a');
            if (titleEl.length === 0) continue;

            const title = titleEl.text().trim();
            const relativeLink = titleEl.attr('href');
            const fullLink = new URL(relativeLink, url).href;

            // Generate a unique ID for this notice
            const noticeId = crypto.createHash('md5').update(title + fullLink).digest('hex');

            // Check if this notice was already sent
            const noticeRef = db.collection('sent_notices').doc(noticeId);
            const doc = await noticeRef.get();

            if (!doc.exists) {
                console.log('New notice detected:', title);

                // 1. Store in Firestore to prevent duplicates
                await noticeRef.set({
                    title: title,
                    link: fullLink,
                    sentAt: admin.firestore.FieldValue.serverTimestamp()
                });

                // 2. Send FCM Push Notification to 'notices' topic
                const message = {
                    notification: {
                        title: '[대학소식] 새 공지사항',
                        body: title,
                    },
                    data: {
                        notice_id: noticeId, // The app uses this to avoid double-notifying if local polling also finds it
                        link: fullLink,
                        category: '대학소식'
                    },
                    topic: 'notices',
                };

                await admin.messaging().send(message);
            }
        }

        return null;
    } catch (error) {
        console.error('Scraping error:', error);
        return null;
    }
});

/**
 * Optional: Cleanup old sent_notices docs to keep Firestore clean (e.g., once a month)
 */
exports.cleanupSentNotices = functions.pubsub.schedule('0 0 1 * *').onRun(async (context) => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const snapshot = await db.collection('sent_notices')
        .where('sentAt', '<', thirtyDaysAgo)
        .get();

    if (snapshot.empty) return null;

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
    });

    await batch.commit();
    console.log(`Deleted ${snapshot.size} old notices.`);
    return null;
});
