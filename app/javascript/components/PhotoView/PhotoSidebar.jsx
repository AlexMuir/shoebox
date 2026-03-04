import React from 'react'

export function PhotoSidebar({ photoData, photoId }) {
  if (!photoData) return null

  return (
    <div className="photo-view-modal__sidebar">
      <div className="card border-0 rounded-0 h-100">
        <div className="card-header">
          <h3 className="card-title">Details</h3>
        </div>
        <div className="card-body">
          <dl className="row mb-4">
            {photoData.date_text && (
              <>
                <dt className="col-5 text-muted">Date</dt>
                <dd className="col-7">{photoData.date_text}</dd>
              </>
            )}
            {photoData.location?.name && (
              <>
                <dt className="col-5 text-muted">Location</dt>
                <dd className="col-7">{photoData.location.name}</dd>
              </>
            )}
            {photoData.event?.title && (
              <>
                <dt className="col-5 text-muted">Event</dt>
                <dd className="col-7">{photoData.event.title}</dd>
              </>
            )}
            {photoData.photographer?.name && (
              <>
                <dt className="col-5 text-muted">Photographer</dt>
                <dd className="col-7">{photoData.photographer.name}</dd>
              </>
            )}
          </dl>

          {photoData.people && photoData.people.length > 0 && (
            <div className="mb-4">
              <h4 className="card-title fs-5 mb-2">People</h4>
              <div className="d-flex flex-wrap gap-2">
                {photoData.people.map(person => (
                  <span key={person.id} className="badge bg-primary-lt">
                    {person.name}
                  </span>
                ))}
              </div>
            </div>
          )}

          {photoData.contributions && photoData.contributions.length > 0 && (
            <div className="mb-4">
              <h4 className="card-title fs-5 mb-2">Contributions</h4>
              <div className="d-flex flex-column gap-3">
                {photoData.contributions.map(contribution => (
                  <div key={contribution.id} className="border-start border-2 border-primary ps-3">
                    <div className="fw-bold">{contribution.field_name}</div>
                    <div>{contribution.value}</div>
                    {contribution.note && <div className="text-muted small mt-1">{contribution.note}</div>}
                    <div className="text-muted small mt-1">
                      By {contribution.user_email} on {new Date(contribution.created_at).toLocaleDateString()}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          <div className="mt-auto pt-4">
            <a href={`/photos/${photoId}`} className="btn btn-outline-primary w-100" target="_self">
              View full details →
            </a>
          </div>
        </div>
      </div>
    </div>
  )
}
