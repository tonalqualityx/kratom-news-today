(function() {
  const form = document.querySelector('.newsletter-form');
  if (!form) return;

  form.addEventListener('submit', async function(e) {
    e.preventDefault();

    const emailInput = form.querySelector('input[type="email"]');
    const statusEl = form.closest('.newsletter-signup').querySelector('.newsletter-status');
    const submitBtn = form.querySelector('button[type="submit"]');
    const email = emailInput.value.trim();

    if (!email) return;

    const companyId = form.dataset.companyId;
    const listId = form.dataset.listId;

    if (!companyId || companyId === 'PLACEHOLDER_KLAVIYO_PUBLIC_KEY') {
      statusEl.textContent = 'Newsletter signup is not yet configured. Check back soon.';
      statusEl.className = 'newsletter-status error';
      return;
    }

    submitBtn.disabled = true;
    submitBtn.textContent = 'Subscribing...';
    statusEl.textContent = '';
    statusEl.className = 'newsletter-status';

    try {
      const response = await fetch('https://a.klaviyo.com/client/subscriptions/?company_id=' + encodeURIComponent(companyId), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'revision': '2024-02-15'
        },
        body: JSON.stringify({
          data: {
            type: 'subscription',
            attributes: {
              profile: {
                data: {
                  type: 'profile',
                  attributes: { email: email }
                }
              }
            },
            relationships: {
              list: {
                data: { type: 'list', id: listId }
              }
            }
          }
        })
      });

      if (response.ok || response.status === 202) {
        statusEl.textContent = 'Thanks for signing up for daily briefings!';
        statusEl.className = 'newsletter-status success';
        emailInput.value = '';
      } else {
        throw new Error('Subscription failed');
      }
    } catch (err) {
      statusEl.textContent = 'Something went wrong. Please try again.';
      statusEl.className = 'newsletter-status error';
    } finally {
      submitBtn.disabled = false;
      submitBtn.textContent = 'Subscribe';
    }
  });
})();
